import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../kiosk/modals/intercom_modal.dart';
import '../kiosk/theme/kiosk_icons.dart';
import '../kiosk/theme/kiosk_tokens.dart';
import 'door_station_stub.dart' if (dart.library.io) 'door_station_io.dart';
import 'door_video.dart';

/// Where the door station lives and how to log into it. The kiosk talks to a
/// Hikvision villa door station (DS-KV series) directly over its ISAPI HTTP
/// API — no Home Assistant in the path — reachable on the intercom VLAN the
/// Pi is bridged onto (see the hikvision-indoor-station project notes).
class DoorStationConfig {
  const DoorStationConfig({
    required this.host,
    required this.username,
    required this.password,
    this.port = 80,
    this.channel = 101,
    this.doorNo = 1,
    this.rtspChannel = 102,
  });

  final String host;
  final String username;
  final String password;
  final int port;

  /// Streaming channel for the camera: 101 = main stream, 102 = sub.
  final int channel;

  /// Which lock relay `RemoteControlDoor` opens (the KV8413 has 1–2).
  final int doorNo;

  /// RTSP channel for the live view. 102 (640×480 sub) is the default: same
  /// ~1s startup as the 1080p main but far lighter to decode and lower latency
  /// on the Pi. Its auth is disabled on the door (see project notes), so the
  /// URL carries no credentials.
  final int rtspChannel;

  String get base => 'http://$host:$port';

  /// Credential-less RTSP URL for the sub-stream (auth disabled on it).
  String get rtspUrl => 'rtsp://$host:554/Streaming/Channels/$rtspChannel';

  /// Credential-less RTSP URL for the 1080p main stream (HD toggle).
  String get rtspUrlMain => 'rtsp://$host:554/Streaming/Channels/$channel';
}

/// A Hikvision door station spoken to over ISAPI. The real implementation
/// (dart:io, [makeDoorStation] in door_station_io.dart) handles the
/// session-login auth, snapshot polling and door unlock; the web build gets
/// a no-op stub so the app still compiles for browser preview.
abstract class DoorStation {
  /// One JPEG frame from the door camera, or null if it couldn't be fetched
  /// (network blip, auth re-login in progress). Callers keep showing the
  /// previous frame rather than flashing an error on a single miss. [channel]
  /// picks the stream (101 main/HD, 102 sub/SD); defaults to the config channel.
  Future<Uint8List?> snapshot({int? channel});

  /// Pulse the door-lock relay open. Throws on failure so the UI can toast.
  Future<void> unlock();

  /// Credential-less RTSP URLs of the sub (default) and main (HD) streams.
  /// Empty on the web stub.
  String get rtspUrl;
  String get rtspUrlMain;

  void dispose();
}

/// Builds the platform-appropriate door station client (real on the Pi,
/// no-op on web).
DoorStation createDoorStation(DoorStationConfig config) => makeDoorStation(config);

/// Drives the kiosk's existing intercom UI ([IntercomController]) from a live
/// door station. Video, the door's sound (one way, through the monitor's
/// speakers) and door-open are wired; talking back is not — the Pi has no
/// microphone yet.
class DoorStationIntercom implements IntercomController {
  // Sound comes from the sub-stream: a second session on the 1080p main
  // stream (which the video is already playing) made the door send it twice,
  // halving the video's frame rate. The sub-stream's video is tiny.
  DoorStationIntercom(this.station) : _doorAudio = DoorAudio(station.rtspUrl) {
    _audio.addListener(() => _doorAudio.setPlaying(_audio.value));
  }

  final DoorStation station;
  final DoorAudio _doorAudio;

  @override
  bool get connected => true;

  final _videoStatus = ValueNotifier(IntercomVideoStatus.connecting);

  /// Whether the door's sound should be playing: on in a call, off while just
  /// looking (so a glance at the camera doesn't play street noise).
  final _audio = ValueNotifier(false);

  // Live RTSP video (gstreamer on the Pi), with the snapshot view as the
  // during-connect / failure fallback so there's always a picture. Its state
  // drives the modal's header badge through [videoStatus].
  @override
  Widget? videoView() => doorLiveVideo(
    station.rtspUrl,
    station.rtspUrlMain,
    status: _videoStatus,
    audio: _audio,
    fallback: DoorCameraView(station: station),
  );

  @override
  ValueListenable<IntercomVideoStatus> get videoStatus => _videoStatus;

  @override
  Future<Uint8List?> snapshot() => station.snapshot();

  // Ring auto-popup is driven separately by the SDK ring-watcher (polls the
  // user's own KH8350 indoor station); wired in a later step.
  @override
  Stream<IntercomMode>? get callEvents => null;

  // A "call" is local for now: answering unmutes the door's sound, hanging up
  // mutes it again. Nothing is signalled to the door station, and with no
  // mic nothing is sent back to it.
  @override
  Future<void> answer() async => _audio.value = true;

  @override
  Future<void> hangUp() async => _audio.value = false;

  @override
  Future<void> setMuted(bool muted) async => _audio.value = !muted;

  @override
  Future<void> unlock() => station.unlock();

  @override
  Duration get unlockHold => const Duration(seconds: 5);
}

/// A snapshot view of the door camera, used as the fallback while the live RTSP
/// player connects (or if it fails). Polls the JPEG `.../picture` endpoint a
/// couple of times a second and swaps frames with `gaplessPlayback` so there's
/// no flicker. The live player ([doorLiveVideo]) overlays its own status chip
/// and HD toggle on top of this, so this stays a plain image.
class DoorCameraView extends StatefulWidget {
  const DoorCameraView({super.key, required this.station, this.fps = 2});

  final DoorStation station;
  final double fps;

  @override
  State<DoorCameraView> createState() => _DoorCameraViewState();
}

class _DoorCameraViewState extends State<DoorCameraView> {
  Timer? _timer;
  Uint8List? _frame;
  bool _inFlight = false;
  bool _everLoaded = false;

  @override
  void initState() {
    super.initState();
    _tick();
    final period = Duration(milliseconds: (1000 / widget.fps).round().clamp(200, 5000));
    _timer = Timer.periodic(period, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_inFlight || !mounted) return;
    _inFlight = true;
    try {
      final bytes = await widget.station.snapshot();
      if (bytes != null && bytes.isNotEmpty && mounted) {
        setState(() {
          _frame = bytes;
          _everLoaded = true;
        });
      }
    } finally {
      _inFlight = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (frame != null) {
      return Image.memory(
        frame,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const KIcon(KIcons.video, size: 64, color: Color(0xFF9AA0A6), stroke: 1.5),
        const SizedBox(height: 14),
        Text(
          _everLoaded ? 'A reconectar à câmara…' : 'A ligar à câmara da porta do prédio…',
          style: KText.s(22, color: const Color(0xFF9AA0A6)),
        ),
      ],
    );
  }
}
