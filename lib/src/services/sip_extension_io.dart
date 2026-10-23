import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'doorbell_watcher.dart';
import 'sip_extension.dart';

SipExtension startSipExtension(SipExtensionConfig config) => _SipUa(config)..start();

String _md5(String s) => md5.convert(utf8.encode(s)).toString();

/// The incoming call we're currently in a dialog with (one at a time — a door
/// station rings one call). Keeps what we need to reply in-dialog (answer,
/// INFO unlock, BYE).
class _Dialog {
  _Dialog({
    required this.inviteMsg,
    required this.callId,
    required this.remoteFrom,
    required this.remoteUri,
    required this.remoteAddr,
    required this.remotePort,
    required this.localTag,
    required this.media,
  });

  final String inviteMsg; // the raw INVITE, to echo Via/CSeq on provisional replies
  final String callId;
  final String remoteFrom; // their full From header (identity + their tag)
  final String remoteUri; // sip:…@…:port to address in-dialog requests to
  final InternetAddress remoteAddr;
  final int remotePort;
  final String localTag; // our To-tag, reused for in-dialog From
  final SipCallMedia media;
  int localCseq = 1;
  bool answered = false;
}

/// Pure-Dart SIP indoor extension. Event-driven over one UDP socket: REGISTER
/// with MD5 digest (admin password), re-register before expiry, and treat an
/// incoming INVITE as the doorbell.
class _SipUa implements SipExtension {
  _SipUa(this.config);

  final SipExtensionConfig config;
  final _rand = Random();

  RawDatagramSocket? _sock;
  String _localIp = '0.0.0.0';

  final _calls = StreamController<IndoorCallStatus>.broadcast();
  final _problem = ValueNotifier<String?>('A ligar à estação principal (SIP)…');
  Timer? _keepalive;
  Timer? _startupGrace;
  Timer? _ringTimeout;
  bool _disposed = false;

  // Registration transaction state.
  int _regCseq = 0;
  String _regCallId = '';
  String _regTag = '';
  String _regLine = '';
  bool _regAuthSent = false;
  bool _registered = false;

  _Dialog? _call;

  @override
  Stream<IndoorCallStatus> get calls => _calls.stream;

  @override
  ValueListenable<String?> get problem => _problem;

  @override
  SipCallMedia? get activeMedia => _call?.media;

  // ---------------------------------------------------------------- lifecycle
  Future<void> start() async {
    // Give the first registration a moment before shouting that it's down.
    _startupGrace = Timer(const Duration(seconds: 20), () {
      if (!_registered) _problem.value = 'Sem ligação à estação principal (SIP ${config.server}).';
    });
    try {
      _localIp = await _resolveLocalIp();
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, config.localPort);
      _sock = s;
      s.listen(_onEvent, onError: (Object e) => debugPrint('[sip] socket error: $e'));
      debugPrint('[sip] UA ${config.number} @ $_localIp:${config.localPort} -> ${config.server}:${config.serverPort}');
      _register();
      // Re-register comfortably before Expires lapses.
      final every = (config.expires * 2 / 3).clamp(30, 3600).round();
      _keepalive = Timer.periodic(Duration(seconds: every), (_) => _register());
    } catch (e) {
      debugPrint('[sip] start failed: $e');
      _problem.value = 'Não consegui arrancar a extensão SIP: $e';
    }
  }

  /// The address on our side of the intercom subnet — what we put in Via/
  /// Contact/SDP so the station sends the INVITE and RTP back to us.
  Future<String> _resolveLocalIp() async {
    final serverParts = config.server.split('.');
    final prefix = serverParts.length == 4 ? '${serverParts[0]}.${serverParts[1]}.${serverParts[2]}.' : null;
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    String? fallback;
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        fallback ??= addr.address;
        if (prefix != null && addr.address.startsWith(prefix)) return addr.address;
      }
    }
    return fallback ?? '0.0.0.0';
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _sock?.receive();
    if (dg == null) return;
    final msg = utf8.decode(dg.data, allowMalformed: true);
    try {
      _onMessage(msg, dg.address, dg.port);
    } catch (e) {
      debugPrint('[sip] handle error: $e');
    }
  }

  // ----------------------------------------------------------------- messages
  void _onMessage(String msg, InternetAddress addr, int port) {
    final start = msg.split('\r\n').first;
    if (start.startsWith('SIP/2.0')) {
      _onResponse(msg, start);
    } else {
      final method = start.split(' ').first;
      switch (method) {
        case 'INVITE':
          _onInvite(msg, addr, port);
        case 'BYE':
          _reply(msg, addr, port, '200 OK');
          debugPrint('[sip] remote hung up');
          _endCall();
        case 'CANCEL':
          _reply(msg, addr, port, '200 OK');
          _endCall();
        case 'OPTIONS':
        case 'MESSAGE':
        case 'INFO':
          _reply(msg, addr, port, '200 OK');
        case 'ACK':
          break; // call is established; nothing to answer
        default:
          _reply(msg, addr, port, '200 OK');
      }
    }
  }

  void _onResponse(String msg, String start) {
    final cseq = _header(msg, 'CSeq') ?? '';
    if (cseq.contains('REGISTER')) {
      if (start.contains(' 401 ') || start.contains(' 407 ')) {
        if (!_regAuthSent) {
          _regAuthSent = true;
          _sendRegister(challenge: msg);
        }
      } else if (start.contains(' 200 ')) {
        if (!_registered) debugPrint('[sip] REGISTERED');
        _registered = true;
        _startupGrace?.cancel();
        _problem.value = null;
      } else if (start.contains(' 403 ')) {
        _problem.value = 'Registo SIP recusado (número/senha). Verifique a extensão e a password de admin.';
      }
    }
    // Responses to our INFO/BYE need no action.
  }

  // --------------------------------------------------------------- REGISTER
  static const _regBody =
      '<regXML>\n<version>V2.0.0</version>\n<regDevName>Pi Extension</regDevName>\n'
      '<regDevSerial>PI000000001</regDevSerial>\n<regDevMacAddr>{mac}</regDevMacAddr>\n</regXML>\n';

  void _register() {
    if (_disposed) return;
    // Fresh transaction each cycle.
    _regCseq++;
    _regCallId = 'reg-${config.number}-${DateTime.now().millisecondsSinceEpoch}';
    _regTag = _token();
    _regLine = _hex(14);
    _regAuthSent = false;
    _sendRegister();
  }

  void _sendRegister({String? challenge}) {
    final ruri = 'sip:${config.number}@${config.server}:${config.serverPort}';
    final to = 'Pi Extension <sip:${config.number}@$_localIp>';
    final body = _regBody.replaceFirst('{mac}', config.mac);
    _regCseq++;
    var auth = '';
    if (challenge != null) {
      final nonce = _quoted(challenge, 'nonce');
      final realm = _quoted(challenge, 'realm') ?? 'Hikvision';
      final opaque = _quoted(challenge, 'opaque');
      final ha1 = _md5('${config.number}:$realm:${config.password}');
      final ha2 = _md5('REGISTER:$ruri');
      final resp = _md5('$ha1:$nonce:$ha2');
      auth = 'Authorization: Digest username="${config.number}", realm="$realm", '
          'nonce="$nonce", uri="$ruri", response="$resp", algorithm=MD5'
          '${opaque != null ? ', opaque="$opaque"' : ''}\r\n';
    }
    final req = StringBuffer()
      ..write('REGISTER $ruri SIP/2.0\r\n')
      ..write('Via: SIP/2.0/UDP $_localIp:${config.localPort};rport;branch=${_branch()}\r\n')
      ..write('From: $to;tag=$_regTag\r\n')
      ..write('To: $to\r\n')
      ..write('Call-ID: $_regCallId\r\n')
      ..write('CSeq: $_regCseq REGISTER\r\n')
      ..write('Contact: <sip:${config.number}@$_localIp:${config.localPort};line=$_regLine>\r\n')
      ..write(auth)
      ..write('Max-Forwards: 70\r\nUser-Agent: HKVS/2.0.0\r\n')
      ..write('Expires: ${config.expires}\r\nContent-Type: text/xml\r\n')
      ..write('Content-Length:   ${body.length}\r\n\r\n')
      ..write(body);
    _sendTo(req.toString(), InternetAddress(config.server), config.serverPort);
  }

  // ----------------------------------------------------------------- INVITE
  void _onInvite(String msg, InternetAddress addr, int port) {
    final callId = _header(msg, 'Call-ID') ?? '';
    // A re-INVITE for the call we're already in (e.g. media renegotiation):
    // acknowledge without re-ringing. Re-send 200 if we'd answered, else 180.
    final existing = _call;
    if (existing != null && existing.callId == callId) {
      if (existing.answered) {
        answer();
      } else {
        _reply(msg, addr, port, '180 Ringing', toTag: existing.localTag);
      }
      return;
    }
    final body = msg.contains('\r\n\r\n') ? msg.split('\r\n\r\n').skip(1).join('\r\n\r\n') : '';
    final cIp = _re(body, r'c=IN IP4 ([\d.]+)') ?? addr.address;
    final aPort = int.tryParse(_re(body, r'm=audio (\d+)') ?? '') ?? 0;
    final vPort = int.tryParse(_re(body, r'm=video (\d+)') ?? '') ?? 0;
    final from = _header(msg, 'From') ?? '';
    final contact = _header(msg, 'Contact');
    final remoteUri = _re(contact ?? '', r'<(sip:[^>;]+)') ?? _re(from, r'<(sip:[^>;]+)') ?? 'sip:${config.server}';
    _call = _Dialog(
      inviteMsg: msg,
      callId: callId,
      remoteFrom: from,
      remoteUri: remoteUri,
      remoteAddr: addr,
      remotePort: port,
      localTag: _token(),
      media: SipCallMedia(doorIp: cIp, audioPort: aPort, videoPort: vPort),
    );
    debugPrint('[sip] INVITE from $from — media $cIp audio:$aPort video:$vPort');
    _problem.value = null;
    _reply(msg, addr, port, '100 Trying');
    _reply(msg, addr, port, '180 Ringing', toTag: _call!.localTag);
    _calls.add(IndoorCallStatus.ringing);
    // Backstop: if the station never CANCELs/BYEs (e.g. the main station
    // answered and no CANCEL reached us) and we don't answer, clear the ring
    // so the UI can't ring forever.
    _ringTimeout?.cancel();
    _ringTimeout = Timer(config.ringTimeout, () {
      final c = _call;
      if (c != null && !c.answered) {
        debugPrint('[sip] ring unanswered/uncancelled after ${config.ringTimeout.inSeconds}s — clearing');
        _endCall();
      }
    });
  }

  @override
  void answer() {
    final c = _call;
    if (c == null || c.answered) return;
    final sdp = StringBuffer()
      ..write('v=0\r\n')
      ..write('o=${config.number} 0 0 IN IP4 $_localIp\r\n')
      ..write('s=Talk session\r\nc=IN IP4 $_localIp\r\nt=0 0\r\n')
      ..write('m=audio ${config.audioPort} RTP/AVP 0 8 101\r\n')
      ..write('a=rtpmap:0 PCMU/8000\r\na=rtpmap:8 PCMA/8000\r\n')
      ..write('a=rtpmap:101 telephone-event/8000\r\na=sendrecv\r\n')
      ..write('m=video ${config.videoPort} RTP/AVP 96\r\n')
      ..write('a=rtpmap:96 H264/90000\r\na=recvonly\r\n');
    _reply(
      c.inviteMsg,
      c.remoteAddr,
      c.remotePort,
      '200 OK',
      toTag: c.localTag,
      extra: 'Contact: <sip:${config.number}@$_localIp:${config.localPort}>\r\n'
          'Content-Type: application/sdp\r\nContent-Length: ${sdp.length}\r\n',
      body: sdp.toString(),
    );
    c.answered = true;
    _ringTimeout?.cancel();
    _calls.add(IndoorCallStatus.onCall);
    debugPrint('[sip] answered — media should flow to $_localIp:${config.audioPort}/${config.videoPort}');
  }

  @override
  bool unlockViaInfo() {
    final c = _call;
    if (c == null) return false;
    const body = 'Signal=#\r\nDuration=160\r\n';
    c.localCseq++;
    final req = StringBuffer()
      ..write('INFO ${c.remoteUri} SIP/2.0\r\n')
      ..write('Via: SIP/2.0/UDP $_localIp:${config.localPort};rport;branch=${_branch()}\r\n')
      ..write('From: <sip:${config.number}@$_localIp:${config.localPort}>;tag=${c.localTag}\r\n')
      ..write('To: ${c.remoteFrom}\r\n')
      ..write('Call-ID: ${c.callId}\r\n')
      ..write('CSeq: ${c.localCseq} INFO\r\n')
      ..write('Contact: <sip:${config.number}@$_localIp:${config.localPort}>\r\n')
      ..write('Max-Forwards: 70\r\nUser-Agent: HKVS/2.0.0\r\n')
      ..write('Content-Type: application/dtmf-relay\r\nContent-Length: ${body.length}\r\n\r\n')
      ..write(body);
    _sendTo(req.toString(), c.remoteAddr, c.remotePort);
    debugPrint('[sip] unlock INFO Signal=# sent');
    return true;
  }

  @override
  void hangup() {
    final c = _call;
    if (c == null) return;
    c.localCseq++;
    final req = StringBuffer()
      ..write('BYE ${c.remoteUri} SIP/2.0\r\n')
      ..write('Via: SIP/2.0/UDP $_localIp:${config.localPort};rport;branch=${_branch()}\r\n')
      ..write('From: <sip:${config.number}@$_localIp:${config.localPort}>;tag=${c.localTag}\r\n')
      ..write('To: ${c.remoteFrom}\r\n')
      ..write('Call-ID: ${c.callId}\r\n')
      ..write('CSeq: ${c.localCseq} BYE\r\n')
      ..write('Max-Forwards: 70\r\nContent-Length: 0\r\n\r\n');
    _sendTo(req.toString(), c.remoteAddr, c.remotePort);
    debugPrint('[sip] BYE sent');
    _endCall();
  }

  void _endCall() {
    _ringTimeout?.cancel();
    _ringTimeout = null;
    if (_call == null) return;
    _call = null;
    _calls.add(IndoorCallStatus.idle);
  }

  // ------------------------------------------------------------------ helpers
  /// Builds a status reply by echoing the request's Via/From/To/Call-ID/CSeq,
  /// adding our To-tag, and appending any [extra] headers + [body].
  void _reply(
    String req,
    InternetAddress addr,
    int port,
    String status, {
    String? toTag,
    String extra = '',
    String body = '',
  }) {
    final via = _header(req, 'Via') ?? '';
    final from = _header(req, 'From') ?? '';
    var to = _header(req, 'To') ?? '';
    final cid = _header(req, 'Call-ID') ?? '';
    final cseq = _header(req, 'CSeq') ?? '';
    if (!to.contains(';tag=')) to = '$to;tag=${toTag ?? _token()}';
    final res = StringBuffer()
      ..write('SIP/2.0 $status\r\n')
      ..write('Via: $via\r\n')
      ..write('From: $from\r\n')
      ..write('To: $to\r\n')
      ..write('Call-ID: $cid\r\n')
      ..write('CSeq: $cseq\r\n')
      ..write('User-Agent: HKVS/2.0.0\r\n')
      ..write(extra)
      ..write('Content-Length: ${body.length}\r\n\r\n')
      ..write(body);
    _sendTo(res.toString(), addr, port);
  }

  void _sendTo(String msg, InternetAddress addr, int port) {
    final s = _sock;
    if (s == null) return;
    s.send(utf8.encode(msg), addr, port);
  }

  String? _header(String msg, String name) {
    final re = RegExp('^$name:\\s*(.+)\$', multiLine: true, caseSensitive: false);
    return re.firstMatch(msg)?.group(1)?.trim();
  }

  String? _quoted(String msg, String key) => RegExp('$key="([^"]+)"').firstMatch(msg)?.group(1);

  String? _re(String s, String pattern) => RegExp(pattern).firstMatch(s)?.group(1);

  String _token() => _rand.nextInt(0x7fffffff).toString();
  String _branch() => 'z9hG4bK${_rand.nextInt(0x7fffffff)}';
  String _hex(int n) {
    const chars = '0123456789abcdef';
    return List.generate(n, (_) => chars[_rand.nextInt(16)]).join();
  }

  @override
  void dispose() {
    _disposed = true;
    _keepalive?.cancel();
    _startupGrace?.cancel();
    _ringTimeout?.cancel();
    _sock?.close();
    _calls.close();
    _problem.dispose();
  }
}
