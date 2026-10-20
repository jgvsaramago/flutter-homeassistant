import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../ha_client/ha_connection_config.dart';
import '../ha_client/ha_websocket_client.dart';
import 'ma_models.dart';

enum MaConnectionState { disconnected, connecting, connected, unavailable }

class MaEvent {
  const MaEvent(this.event, this.objectId, this.data);

  final String event;
  final String? objectId;
  final dynamic data;
}

/// Music Assistant's own websocket API, reached through Home Assistant's
/// ingress for the MA add-on — the same way MA's panel in HA's sidebar
/// works. HA authenticates the screen (with the token it already has) and
/// MA trusts HA's ingress, so no MA token is needed: the add-on's ingress
/// path and a session come from the Supervisor via HA's websocket.
///
/// Sessions expire unless validated, so one is refreshed every few
/// minutes; a dropped socket reconnects on a backoff, like the HA client.
class MaClient {
  MaClient(this._ha, this._config);

  final HaWebSocketClient _ha;
  final HaConnectionConfig _config;

  String? _entry;
  String? _session;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _keepAlive;
  Timer? _retry;
  int _attempt = 0;
  bool _stopped = false;
  bool _connecting = false;
  int _nextId = 1;
  final _pending = <String, Completer<dynamic>>{};
  final _partials = <String, List<dynamic>>{};

  final state = ValueNotifier<MaConnectionState>(MaConnectionState.disconnected);
  final _events = StreamController<MaEvent>.broadcast();
  Stream<MaEvent> get events => _events.stream;

  static const _backoff = [Duration(seconds: 3), Duration(seconds: 10), Duration(seconds: 30), Duration(seconds: 60)];

  String get _base => _config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  /// Headers an image loaded through the ingress needs.
  Map<String, String> get imageHeaders => _session == null ? const {} : {'Cookie': 'ingress_session=$_session'};

  /// A loadable URL for [image]: remote ones as they are, local ones
  /// through MA's image proxy (with [imageHeaders]).
  String? imageUrl(MaImage? image) {
    if (image == null) return null;
    if (image.remote) return image.path;
    if (image.proxyId == null || _entry == null) return null;
    return '$_base$_entry/imageproxy/${image.proxyId}';
  }

  void start() {
    _stopped = false;
    if (kIsWeb) {
      // No custom headers on a browser websocket, so no ingress cookie.
      state.value = MaConnectionState.unavailable;
      return;
    }
    unawaited(_connect());
  }

  Future<void> stop() async {
    _stopped = true;
    _retry?.cancel();
    _keepAlive?.cancel();
    await _drop();
    state.value = MaConnectionState.disconnected;
  }

  Future<void> _connect() async {
    if (_stopped || _connecting) return;
    _connecting = true;
    state.value = MaConnectionState.connecting;
    try {
      _entry ??= await _findIngressEntry();
      if (_entry == null) {
        state.value = MaConnectionState.unavailable;
        _connecting = false;
        _scheduleRetry(long: true);
        return;
      }
      final session = await _ha.supervisorApi('/ingress/session', method: 'post');
      _session = (session as Map)['session'] as String;
      final wsBase = _base.replaceFirst(RegExp(r'^http'), 'ws');
      final channel = IOWebSocketChannel.connect(
        Uri.parse('$wsBase$_entry/ws'),
        headers: {'Cookie': 'ingress_session=$_session'},
        connectTimeout: const Duration(seconds: 15),
      );
      await channel.ready.timeout(const Duration(seconds: 15));
      final greeted = Completer<void>();
      _channel = channel;
      _sub = channel.stream.listen(
        (raw) {
          if (!greeted.isCompleted) {
            greeted.complete(); // MA's unprompted server-info greeting
            return;
          }
          _onMessage(raw);
        },
        onError: (Object e) => _onClosed('error: $e'),
        onDone: () => _onClosed('closed'),
        cancelOnError: true,
      );
      await greeted.future.timeout(const Duration(seconds: 15));
      _attempt = 0;
      state.value = MaConnectionState.connected;
      debugPrint('[music assistant] connected through ingress');
      _keepAlive?.cancel();
      _keepAlive = Timer.periodic(const Duration(minutes: 4), (_) => _validateSession());
    } catch (e) {
      debugPrint('[music assistant] connect failed: $e');
      await _drop();
      state.value = MaConnectionState.disconnected;
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  Future<String?> _findIngressEntry() async {
    final addons = await _ha.supervisorApi('/addons');
    final list = (addons is Map ? addons['addons'] : null) as List? ?? const [];
    final ma = list.whereType<Map>().where((a) => '${a['slug']}'.contains('music_assistant')).firstOrNull;
    if (ma == null) return null;
    final info = await _ha.supervisorApi('/addons/${ma['slug']}/info');
    return (info as Map)['ingress_entry'] as String?;
  }

  Future<void> _validateSession() async {
    final s = _session;
    if (s == null) return;
    try {
      await _ha.supervisorApi('/ingress/validate_session', method: 'post', data: {'session': s});
    } catch (e) {
      debugPrint('[music assistant] session refresh failed ($e); reconnecting');
      await _drop();
      state.value = MaConnectionState.disconnected;
      _scheduleRetry();
    }
  }

  void _onClosed(String why) {
    if (_channel == null) return;
    debugPrint('[music assistant] connection $why');
    unawaited(_drop());
    state.value = MaConnectionState.disconnected;
    _scheduleRetry();
  }

  Future<void> _drop() async {
    _keepAlive?.cancel();
    final sub = _sub;
    final channel = _channel;
    _sub = null;
    _channel = null;
    await sub?.cancel();
    if (channel != null) unawaited(channel.sink.close().timeout(const Duration(seconds: 2), onTimeout: () {}).catchError((Object _) {}));
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('Music Assistant disconnected'));
    }
    _pending.clear();
    _partials.clear();
  }

  void _scheduleRetry({bool long = false}) {
    if (_stopped) return;
    _retry?.cancel();
    final delay = long ? const Duration(minutes: 5) : _backoff[_attempt.clamp(0, _backoff.length - 1)];
    _attempt++;
    _retry = Timer(delay, () => unawaited(_connect()));
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> m;
    try {
      m = (jsonDecode(raw as String) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    if (m.containsKey('event')) {
      _events.add(MaEvent(m['event'] as String, m['object_id'] as String?, m['data']));
      return;
    }
    final id = m['message_id']?.toString();
    if (id == null) return;
    if (m['partial'] == true) {
      (_partials[id] ??= []).addAll(m['result'] as List? ?? const []);
      return;
    }
    final c = _pending.remove(id);
    final partial = _partials.remove(id);
    if (c == null) return;
    if (m.containsKey('error_code')) {
      c.completeError(StateError('${m['details'] ?? m['error_code']}'));
      return;
    }
    final result = m['result'];
    c.complete(partial != null && result is List ? [...partial, ...result] : (partial ?? result));
  }

  /// Sends [command] and waits for its result.
  Future<dynamic> call(String command, [Map<String, dynamic>? args]) {
    final channel = _channel;
    if (channel == null || state.value != MaConnectionState.connected) {
      return Future.error(StateError('Music Assistant não está ligado'));
    }
    final id = '${_nextId++}';
    final c = Completer<dynamic>();
    _pending[id] = c;
    channel.sink.add(jsonEncode({'command': command, 'message_id': id, 'args': ?args}));
    return c.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        _pending.remove(id);
        _partials.remove(id);
        throw TimeoutException('Sem resposta do Music Assistant ($command)');
      },
    );
  }
}
