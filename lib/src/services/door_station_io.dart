import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'door_station.dart';

DoorStation makeDoorStation(DoorStationConfig config) => HikDoorStation(config);

/// ISAPI client for a Hikvision villa door station.
///
/// The KV8413 rejects plain HTTP basic/digest and only accepts Hikvision's
/// salted "session login": GET the login capabilities (salt + per-attempt
/// challenge + iteration count), hash the password through that, POST it, and
/// carry the returned `WebSession…` cookie on every later call. The cookie is
/// cached and silently re-established on a 401, so a dropped session recovers
/// on the next frame without surfacing an error.
class HikDoorStation implements DoorStation {
  HikDoorStation(this.config);

  final DoorStationConfig config;
  final http.Client _http = http.Client();

  String? _cookie;
  Future<void>? _loginInFlight;

  // Backoff after failed logins. Hikvision door stations lock the source IP
  // after a handful of failed auths, and — critically — *extend* that lock on
  // every further attempt during it. The camera view polls ~2x/s, so without
  // this a wrong password or an in-progress lockout would hammer the device
  // forever and the lock would never clear. After a failure we refuse to
  // touch the device again until [_cooldownUntil], backing off further each
  // time, so the app can never be the thing keeping itself locked out.
  DateTime? _cooldownUntil;
  int _failStreak = 0;

  String _sha(String s) => sha256.convert(utf8.encode(s)).toString();

  String _tag(String body, String tag) {
    final m = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(body);
    return m?.group(1)?.trim() ?? '';
  }

  Future<void> _login() async {
    final capUri = Uri.parse(
      '${config.base}/ISAPI/Security/sessionLogin/capabilities?username=${Uri.encodeComponent(config.username)}',
    );
    final cap = await _http.get(capUri).timeout(const Duration(seconds: 8));
    if (cap.statusCode != 200) {
      throw Exception('door login caps: HTTP ${cap.statusCode}');
    }
    final body = cap.body;
    final sessionId = _tag(body, 'sessionID');
    final challenge = _tag(body, 'challenge');
    final salt = _tag(body, 'salt');
    final iterations = int.tryParse(_tag(body, 'iterations')) ?? 100;
    final irreversible = _tag(body, 'isIrreversible').toLowerCase().contains('true');
    final verRaw = _tag(body, 'sessionIDVersion');
    final sessionIdVersion = verRaw.isEmpty ? '2' : verRaw;

    String hashed;
    if (irreversible) {
      hashed = _sha(config.username + salt + config.password);
      hashed = _sha(hashed + challenge);
    } else {
      hashed = _sha(config.password);
      hashed = _sha(hashed + challenge);
    }
    for (var i = 2; i < iterations; i++) {
      hashed = _sha(hashed);
    }

    final xml =
        '<SessionLogin><userName>${config.username}</userName><password>$hashed</password>'
        '<sessionID>$sessionId</sessionID><isSessionIDValidLongTerm>false</isSessionIDValidLongTerm>'
        '<sessionIDVersion>$sessionIdVersion</sessionIDVersion></SessionLogin>';

    final res = await _http
        .post(
          Uri.parse('${config.base}/ISAPI/Security/sessionLogin'),
          headers: const {'Content-Type': 'application/xml'},
          body: xml,
        )
        .timeout(const Duration(seconds: 8));
    final setCookie = res.headers['set-cookie'];
    if (res.statusCode == 200 && setCookie != null && setCookie.isNotEmpty) {
      _cookie = setCookie.split(';').first;
    } else {
      throw Exception('door login: HTTP ${res.statusCode}');
    }
  }

  Future<void> _ensureLogin() async {
    if (_cookie != null) return;
    final until = _cooldownUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      // Still backing off from a recent failure — don't touch the device, or
      // we risk extending a lockout we may already be in.
      throw Exception('door auth backing off until $until');
    }
    // Collapse concurrent callers (the snapshot timer + an unlock tap) onto a
    // single in-flight login instead of hammering the device — which also
    // matters because it locks out after a handful of failed logins.
    _loginInFlight ??= _login().then(
      (_) {
        _failStreak = 0;
        _cooldownUntil = null;
      },
      onError: (Object e) {
        _failStreak++;
        final secs = (15 * _failStreak).clamp(15, 120);
        _cooldownUntil = DateTime.now().add(Duration(seconds: secs));
        throw e;
      },
    ).whenComplete(() => _loginInFlight = null);
    await _loginInFlight;
  }

  /// Runs [send]; if it 401s, drops the cookie, logs in again, and retries
  /// once. Returns the final response.
  Future<http.Response> _authed(Future<http.Response> Function(String cookie) send) async {
    await _ensureLogin();
    var res = await send(_cookie!);
    if (res.statusCode == 401) {
      _cookie = null;
      await _ensureLogin();
      res = await send(_cookie!);
    }
    return res;
  }

  @override
  Future<Uint8List?> snapshot({int? channel}) async {
    final ch = channel ?? config.channel;
    try {
      final res = await _authed(
        (cookie) => _http
            .get(
              Uri.parse('${config.base}/ISAPI/Streaming/channels/$ch/picture'),
              headers: {'Cookie': cookie},
            )
            .timeout(const Duration(seconds: 6)),
      );
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) return res.bodyBytes;
      return null;
    } catch (e) {
      debugPrint('[door] snapshot failed: $e');
      return null;
    }
  }

  @override
  Future<void> unlock() async {
    const xml =
        '<RemoteControlDoor version="2.0" xmlns="http://www.isapi.org/ver20/XMLSchema">'
        '<cmd>open</cmd></RemoteControlDoor>';
    final res = await _authed(
      (cookie) => _http
          .put(
            Uri.parse('${config.base}/ISAPI/AccessControl/RemoteControl/door/${config.doorNo}'),
            headers: {'Cookie': cookie, 'Content-Type': 'application/xml'},
            body: xml,
          )
          .timeout(const Duration(seconds: 8)),
    );
    if (res.statusCode != 200) {
      throw Exception('Não foi possível abrir a porta (HTTP ${res.statusCode})');
    }
  }

  @override
  String get rtspUrl => config.rtspUrl;

  @override
  String get rtspUrlMain => config.rtspUrlMain;

  @override
  void dispose() => _http.close();
}
