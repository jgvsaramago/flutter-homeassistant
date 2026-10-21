import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'doorbell_watcher.dart';

DoorbellWatcher startDoorbellWatcher(IndoorStationConfig config) => _IsolateDoorbellWatcher(config);

/// Runs the HCNetSDK polling loop ([_watch]) on its own isolate — the SDK's
/// calls block — and turns its messages into [calls] and [problem].
///
/// Failures are debounced before they become a [problem] (a dropped poll or a
/// quick re-login shouldn't flash a warning), cleared the moment the link is
/// back, and the isolate is respawned if it ever dies.
class _IsolateDoorbellWatcher implements DoorbellWatcher {
  _IsolateDoorbellWatcher(this.config) {
    _report('Ainda sem ligação ao intercomunicador de casa (${config.host}).', after: _startupGrace);
    _spawn();
  }

  /// How long the first login may take before the warning shows.
  static const _startupGrace = Duration(seconds: 20);

  /// How long the link may be down before the warning shows.
  static const _downGrace = Duration(seconds: 10);

  final IndoorStationConfig config;
  final _calls = StreamController<IndoorCallStatus>.broadcast();
  final _problem = ValueNotifier<String?>(null);
  Timer? _problemTimer;
  String? _pendingProblem;
  bool _disposed = false;
  Isolate? _isolate;

  @override
  Stream<IndoorCallStatus> get calls => _calls.stream;

  @override
  ValueListenable<String?> get problem => _problem;

  /// Shows [message] once the link has been broken for [after] — or at once,
  /// updating the text, if a warning is already up.
  void _report(String message, {Duration after = _downGrace}) {
    _pendingProblem = message;
    if (_problem.value != null) {
      _problem.value = message;
      return;
    }
    _problemTimer ??= Timer(after, () {
      _problemTimer = null;
      _problem.value = _pendingProblem;
    });
  }

  void _healthy() {
    _problemTimer?.cancel();
    _problemTimer = null;
    _pendingProblem = null;
    _problem.value = null;
  }

  Future<void> _spawn() async {
    if (_disposed) return;
    final messages = ReceivePort();
    final errors = ReceivePort();
    final exits = ReceivePort();
    messages.listen(_onMessage);
    errors.listen((e) => debugPrint('[doorbell] watcher isolate error: $e'));
    // An uncaught error is fatal (errorsAreFatal), so it also ends in onExit:
    // restart from there only.
    exits.listen((_) {
      messages.close();
      errors.close();
      exits.close();
      _isolate = null;
      if (_disposed) return;
      debugPrint('[doorbell] watcher isolate exited, restarting');
      _report('A ligação ao intercomunicador de casa parou; a religar.');
      Timer(const Duration(seconds: 5), _spawn);
    });
    try {
      _isolate = await Isolate.spawn(
        _watch,
        _WatchArgs(messages.sendPort, config.host, config.port, config.username, config.password, config.sdkDir),
        onExit: exits.sendPort,
        onError: errors.sendPort,
        errorsAreFatal: true,
        debugName: 'doorbell',
      );
    } catch (e) {
      messages.close();
      errors.close();
      exits.close();
      debugPrint('[doorbell] could not start watcher: $e');
      _report('Não consegui arrancar a ligação ao intercomunicador de casa: $e');
      Timer(const Duration(seconds: 10), _spawn);
    }
  }

  void _onMessage(Object? message) {
    if (message is! List || message.isEmpty) return;
    switch (message[0]) {
      case 'up':
        debugPrint('[doorbell] logged in to the indoor station');
        _healthy();
      case 'down':
        debugPrint('[doorbell] ${message[1]}');
        _report(message[1] as String);
      case 'call':
        _healthy();
        final raw = message[1] as String;
        final status = switch (raw) {
          'ring' => IndoorCallStatus.ringing,
          'onCall' => IndoorCallStatus.onCall,
          _ => IndoorCallStatus.idle,
        };
        debugPrint('[doorbell] indoor station: $raw');
        _calls.add(status);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _problemTimer?.cancel();
    _isolate?.kill(priority: Isolate.immediate);
    _calls.close();
  }
}

class _WatchArgs {
  const _WatchArgs(this.out, this.host, this.port, this.username, this.password, this.sdkDir);

  final SendPort out;
  final String host;
  final int port;
  final String username;
  final String password;
  final String sdkDir;
}

/// `NET_DVR_XML_CONFIG_INPUT` (72 bytes on aarch64).
final class _XmlIn extends Struct {
  @Uint32()
  external int dwSize;
  external Pointer<Utf8> lpRequestUrl;
  @Uint32()
  external int dwRequestUrlLen;
  external Pointer<Void> lpInBuffer;
  @Uint32()
  external int dwInBufferSize;
  @Uint32()
  external int dwRecvTimeOut;
  @Uint8()
  external int byForceEncrpt;
  @Array(31)
  external Array<Uint8> byRes;
}

/// `NET_DVR_XML_CONFIG_OUTPUT` (72 bytes on aarch64).
final class _XmlOut extends Struct {
  @Uint32()
  external int dwSize;
  external Pointer<Uint8> lpOutBuffer;
  @Uint32()
  external int dwOutBufferSize;
  @Uint32()
  external int dwReturnedXMLSize;
  external Pointer<Uint8> lpStatusBuffer;
  @Uint32()
  external int dwStatusSize;
  @Array(31)
  external Array<Uint8> byRes;
}

// NET_DVR_SetSDKInitCfg types.
const _cfgSdkPath = 2;
const _cfgLibeayPath = 3;
const _cfgSsleayPath = 4;

// NET_DVR_GetLastError codes worth telling apart.
const _errPassword = 1;
const _errUserLocked = 153;

const _pollEvery = Duration(milliseconds: 500);
const _outSize = 64 * 1024;
const _statusSize = 4 * 1024;

/// The watcher isolate: log into the indoor station over the HCNetSDK and
/// poll its `callStatus` every [_pollEvery] — the SDK's alarm push is silent
/// for calls on this model (tested), and a doorbell rings for ~30 s, so half
/// a second is effectively instant. Never returns while things work; on a
/// fatal setup error it reports, waits and returns, and the main isolate
/// respawns it.
void _watch(_WatchArgs a) {
  void send(List<Object?> m) => a.out.send(m);

  final DynamicLibrary lib;
  try {
    lib = DynamicLibrary.open('${a.sdkDir}/libhcnetsdk.so');
  } catch (e) {
    send(['down', 'Falta a biblioteca do intercomunicador (${a.sdkDir}/libhcnetsdk.so).']);
    sleep(const Duration(seconds: 30));
    return;
  }

  final setInitCfg = lib.lookupFunction<Int32 Function(Int32, Pointer<Void>), int Function(int, Pointer<Void>)>('NET_DVR_SetSDKInitCfg');
  final init = lib.lookupFunction<Int32 Function(), int Function()>('NET_DVR_Init');
  final setConnectTime = lib.lookupFunction<Int32 Function(Uint32, Uint32), int Function(int, int)>('NET_DVR_SetConnectTime');
  final login = lib.lookupFunction<
    Int32 Function(Pointer<Utf8>, Uint16, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>),
    int Function(Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>)
  >('NET_DVR_Login_V30');
  final logout = lib.lookupFunction<Int32 Function(Int32), int Function(int)>('NET_DVR_Logout');
  final xmlConfig = lib.lookupFunction<
    Int32 Function(Int32, Pointer<_XmlIn>, Pointer<_XmlOut>),
    int Function(int, Pointer<_XmlIn>, Pointer<_XmlOut>)
  >('NET_DVR_STDXMLConfig');
  final lastError = lib.lookupFunction<Uint32 Function(), int Function()>('NET_DVR_GetLastError');

  // Point the SDK at its runtime-loaded parts (HCNetSDKCom/, OpenSSL) so it
  // works regardless of the app's working directory or LD_LIBRARY_PATH.
  final sdkPath = calloc<Uint8>(384); // NET_DVR_LOCAL_SDK_PATH: char sPath[256] + byRes[128]
  final dirBytes = '${a.sdkDir}/'.codeUnits;
  for (var i = 0; i < dirBytes.length && i < 255; i++) {
    sdkPath[i] = dirBytes[i];
  }
  setInitCfg(_cfgSdkPath, sdkPath.cast());
  setInitCfg(_cfgLibeayPath, '${a.sdkDir}/libcrypto.so.1.1'.toNativeUtf8().cast());
  setInitCfg(_cfgSsleayPath, '${a.sdkDir}/libssl.so'.toNativeUtf8().cast());
  if (init() == 0) {
    send(['down', 'O SDK do intercomunicador não arrancou (erro ${lastError()}).']);
    sleep(const Duration(seconds: 30));
    return;
  }
  setConnectTime(3000, 1);

  final host = a.host.toNativeUtf8();
  final user = a.username.toNativeUtf8();
  final password = a.password.toNativeUtf8();
  final deviceInfo = calloc<Uint8>(1024); // NET_DVR_DEVICEINFO_V30, unused
  final url = 'GET /ISAPI/VideoIntercom/callStatus?format=json'.toNativeUtf8();
  final urlLength = url.length;
  final xmlIn = calloc<_XmlIn>();
  final xmlOut = calloc<_XmlOut>();
  final outBuffer = calloc<Uint8>(_outSize);
  final statusBuffer = calloc<Uint8>(_statusSize);
  final statusPattern = RegExp(r'"status"\s*:\s*"(\w+)"');

  var userId = -1;
  var backoff = 5;
  var failures = 0;
  String? last;
  while (true) {
    if (userId < 0) {
      userId = login(host, a.port, user, password, deviceInfo.cast());
      if (userId < 0) {
        final err = lastError();
        // A wrong password or a lockout won't fix itself, and every attempt
        // during a lockout extends it — retry rarely so we can't keep the
        // device locked. Network errors can't lock us out, so they retry
        // soon: at most 15 s, or a ring right after an outage could be missed.
        final wait = err == _errPassword || err == _errUserLocked ? 600 : backoff;
        send([
          'down',
          switch (err) {
            _errPassword => 'Utilizador ou palavra-passe do intercomunicador de casa errados.',
            _errUserLocked => 'O intercomunicador de casa bloqueou o acesso (demasiadas tentativas); nova tentativa em 10 min.',
            _ => 'Não consegui ligar ao intercomunicador de casa (${a.host}, erro $err).',
          },
        ]);
        sleep(Duration(seconds: wait));
        backoff = min(backoff * 2, 15);
        continue;
      }
      backoff = 5;
      failures = 0;
      last = null;
      send(['up']);
    }

    xmlIn.ref
      ..dwSize = sizeOf<_XmlIn>()
      ..lpRequestUrl = url
      ..dwRequestUrlLen = urlLength
      ..lpInBuffer = nullptr
      ..dwInBufferSize = 0
      ..dwRecvTimeOut = 3000;
    xmlOut.ref
      ..dwSize = sizeOf<_XmlOut>()
      ..lpOutBuffer = outBuffer
      ..dwOutBufferSize = _outSize
      ..dwReturnedXMLSize = 0
      ..lpStatusBuffer = statusBuffer
      ..dwStatusSize = _statusSize;

    if (xmlConfig(userId, xmlIn, xmlOut) != 0) {
      failures = 0;
      final length = min(xmlOut.ref.dwReturnedXMLSize, _outSize);
      final body = String.fromCharCodes(outBuffer.asTypedList(length));
      final status = statusPattern.firstMatch(body)?.group(1) ?? 'unknown';
      if (status != last) {
        send(['call', status]);
        last = status;
      }
    } else if (++failures >= 3) {
      send(['down', 'O intercomunicador de casa deixou de responder (erro ${lastError()}); a religar.']);
      logout(userId);
      userId = -1;
      failures = 0;
      sleep(const Duration(seconds: 2));
      continue;
    }
    sleep(_pollEvery);
  }
}
