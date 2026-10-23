import 'package:flutter/foundation.dart';

import 'doorbell_watcher.dart';
import 'sip_extension_stub.dart' if (dart.library.io) 'sip_extension_io.dart' as impl;

/// How to register the Pi as a native Hikvision **indoor extension**.
///
/// This is the reverse-engineered Protocol-2.0 path (validated on the live
/// KH8350, see the hikvision-indoor-station project notes): a plain RFC-3261
/// SIP UA that REGISTERs to the main station's `sipServer` with MD5 digest —
/// the "password" is simply the device **admin password**, and the number is
/// the extension number the station provisioned (e.g. `10000000001`). The Pi
/// must sit **on the intercom VLAN** (same subnet as [server] and the door
/// station's media), or the INVITE/RTP never reach it.
///
/// Replaces the HCNetSDK polling watcher: an incoming `INVITE` *is* the ring,
/// so this also satisfies [DoorbellWatcher]. No proprietary SDK, no port-8000.
class SipExtensionConfig {
  const SipExtensionConfig({
    required this.server,
    required this.number,
    required this.password,
    this.serverPort = 5065,
    this.localPort = 5060,
    this.audioPort = 20000,
    this.videoPort = 20002,
    this.mac = '02:11:22:33:44:55',
    this.expires = 900,
    this.ringTimeout = const Duration(seconds: 60),
  });

  /// The main station's intercom-side IP, which runs the SIP registrar
  /// (`sipServer` on [serverPort]). For this flat that's `192.168.2.2`.
  final String server;
  final int serverPort;

  /// The provisioned extension number (digest username), e.g. `10000000001`.
  final String number;

  /// The device admin password — doubles as the SIP registration password.
  final String password;

  /// The UDP port our UA listens on for SIP (the door sends the INVITE here).
  final int localPort;

  /// Local RTP ports advertised in our answer SDP (audio, then video).
  final int audioPort;
  final int videoPort;

  /// MAC reported in the `<regXML>` body (cosmetic; the station keys auth on
  /// the number + password, not this).
  final String mac;

  /// Registration lifetime, seconds; we re-register well before it lapses.
  final int expires;

  /// Safety backstop: if an incoming call is neither answered here nor
  /// cancelled by the station (e.g. the main station answered and no CANCEL
  /// reached us) within this long, the ring is cleared so the UI can't ring
  /// forever. The station's own CANCEL/BYE normally clears it far sooner.
  final Duration ringTimeout;
}

/// The door's RTP endpoints for the active call, parsed from its INVITE SDP.
/// The media layer (GStreamer) uses these to receive video/audio and to send
/// our microphone back for two-way talk.
@immutable
class SipCallMedia {
  const SipCallMedia({required this.doorIp, required this.audioPort, required this.videoPort});

  /// Where the door streams from / listens (SDP `c=`), e.g. `192.168.2.1`.
  final String doorIp;
  final int audioPort;
  final int videoPort;
}

/// A SIP indoor extension registered to the Hikvision main station.
///
/// It is a [DoorbellWatcher] — [calls] emits [IndoorCallStatus.ringing] on an
/// incoming `INVITE`, [IndoorCallStatus.onCall] once [answer]ed, and
/// [IndoorCallStatus.idle] on hangup — and additionally exposes the call
/// controls and media endpoints the native path needs.
abstract class SipExtension implements DoorbellWatcher {
  /// The door's RTP endpoints while a call is up, else null.
  SipCallMedia? get activeMedia;

  /// Answer the current incoming call: `200 OK` + our SDP. No-op if idle.
  void answer();

  /// End the current call with `BYE`. No-op if idle.
  void hangup();

  /// Open the door *during a call* via in-dialog `INFO` (DTMF `#`), the way a
  /// real indoor extension's unlock button does. Returns false if no call is
  /// up. (ISAPI unlock still works anytime via the door-station client.)
  bool unlockViaInfo();
}

/// Starts the extension (registers + keep-alive) on the Pi; a no-op stub on
/// web so the app still builds for browser preview.
SipExtension startSipExtension(SipExtensionConfig config) => impl.startSipExtension(config);
