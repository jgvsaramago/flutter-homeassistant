import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutterpi_gstreamer_video_player/flutterpi_gstreamer_video_player.dart';
import 'package:video_player/video_player.dart';

import '../kiosk/modals/intercom_modal.dart';

bool _registered = false;

/// Install the flutter-pi gstreamer backend as the video_player platform.
/// Safe to call more than once; must run before the first VideoPlayerController.
void registerDoorVideo() {
  if (_registered) return;
  FlutterpiVideoPlayer.registerWith();
  _registered = true;
}

/// Low-latency pipeline for the door's **1080p H.264 main stream** (channel 101,
/// auth disabled), decoded **in software** (`avdec_h264`).
///
/// Software on purpose. The Pi 5 has no hardware H.264 decoder, and its hardware
/// HEVC decoder (`rpi_hevc_dec`) hung *in the kernel* on this camera's H.265
/// stream — a stuck process that even SIGKILL can't clear, freezing the whole
/// kiosk until a hard reboot. A software decoder can at worst fail inside our
/// process. 1080p25 measured at ~10% of total CPU on the Pi 5 with 0 dropped
/// frames, so there's no need for hardware decode.
///
///  * A leaky queue after the decoder: if the display side ever stops taking
///    frames, old frames are dropped instead of backing up into the decoder.
///    It must hold well over the ~100 ms the synced sink keeps in flight: at
///    2 frames it leaked constantly, thinning the video to 1/2 or 1/3 of 25 fps
///    and often staying there (measured: 1 s of room gives a steady 25 fps,
///    even with the door-audio player starting and stopping alongside).
///  * `videoconvert` passes `avdec_h264`'s I420 straight through (I420 is in
///    the appsink's accepted list); it's only there to adapt if the stream
///    ever decodes to a format the sink doesn't take.
///
/// Video only: the door's sound plays in a separate process ([DoorAudio]).
/// Putting an audio branch in this pipeline made the video's start-up depend
/// on the sound path — it sometimes didn't come up at all.
///
/// Also needs our patched flutter-pi (see project notes): stock flutter-pi
/// never sends `initialized` for a live source, and can't upload 1080p
/// system-memory frames.
///
/// (The sub-stream, channel 102, is what the neighbours' indoor station pulls,
/// and it only delivers ~8 fps — so the main stream is used here.)
String _pipeline(String rtspUrl) =>
    'rtspsrc location=$rtspUrl latency=100 protocols=tcp drop-on-latency=true '
    '! rtph264depay ! h264parse ! avdec_h264 '
    '! queue leaky=downstream max-size-buffers=0 max-size-bytes=0 max-size-time=1000000000 '
    '! videoconvert ! appsink name="sink"';

/// Live door-camera view. Plays the 1080p H.264 main stream; while it connects
/// (~1s) — or if it fails — it shows [fallback] (the snapshot view), so there's
/// always a picture rather than a spinner or black box. [status] reports which
/// of those is on screen, for the intercom modal's header badge. [audio] is
/// reset to off when the view goes away: closing the modal ends the call.
Widget doorLiveVideo(
  String subUrl,
  String mainUrl, {
  required ValueNotifier<IntercomVideoStatus> status,
  required ValueNotifier<bool> audio,
  required Widget fallback,
}) => _DoorVideo(url: mainUrl, status: status, audio: audio, fallback: fallback);

class _DoorVideo extends StatefulWidget {
  const _DoorVideo({required this.url, required this.status, required this.audio, required this.fallback});

  final String url;
  final ValueNotifier<IntercomVideoStatus> status;
  final ValueNotifier<bool> audio;
  final Widget fallback;

  @override
  State<_DoorVideo> createState() => _DoorVideoState();
}

class _DoorVideoState extends State<_DoorVideo> {
  VideoPlayerController? _controller;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    // The notifier outlives this view (it's the controller's), so it may still
    // say "live" from the last time the modal was open. Reset it after this
    // frame — changing it mid-build would rebuild the badge during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_live) widget.status.value = IntercomVideoStatus.connecting;
    });
    _start();
  }

  Future<void> _start() async {
    try {
      final c = FlutterpiVideoPlayerController.withGstreamerPipeline(_pipeline(widget.url));
      _controller = c;
      // Bounded wait: if the backend never reports initialized, don't sit on
      // "connecting" forever — fall back to snapshots with a visible status.
      await c.initialize().timeout(const Duration(seconds: 10));
      await c.play();
      debugPrint('[door] live video initialized: size=${c.value.size} playing=${c.value.isPlaying}');
      if (!mounted) return;
      setState(() => _live = true);
      widget.status.value = IntercomVideoStatus.live;
    } catch (e) {
      debugPrint('[door] live video unavailable ($e), showing snapshots');
      if (mounted) widget.status.value = IntercomVideoStatus.snapshots;
    }
  }

  @override
  void dispose() {
    widget.audio.value = false;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_live && c != null && c.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
      );
    }
    return widget.fallback;
  }
}

/// Plays the door's sound — the RTSP stream's G.711 µ-law track — through
/// PipeWire's pulse socket, which routes to whichever HDMI port the monitor
/// (and its speakers) is on.
///
/// The door has no audio-only stream; its streams carry audio alongside the
/// video, and `rtspsrc` receives both. So [rtspUrl] should be the light
/// sub-stream, not the main stream the video already plays (a second main
/// session halved the video's frame rate).
///
/// Runs as its own `gst-launch-1.0` process with its own RTSP connection, so it
/// can't affect the video: if it fails, the picture carries on and the player
/// is respawned after a pause for as long as sound is wanted. `timeout` caps
/// each run as a backstop against an orphaned player; systemd also kills it
/// with the rest of the service's cgroup on a restart.
class DoorAudio {
  DoorAudio(this.rtspUrl);

  final String rtspUrl;

  bool _wanted = false;
  Process? _process;
  Future<void>? _starting;
  Timer? _respawn;

  void setPlaying(bool on) {
    if (on == _wanted) return;
    _wanted = on;
    if (on) {
      _spawn();
    } else {
      _respawn?.cancel();
      _process?.kill();
      _process = null;
    }
  }

  void _spawn() {
    _respawn?.cancel();
    if (!_wanted || _process != null || _starting != null) return;
    _starting = _startProcess().whenComplete(() => _starting = null);
  }

  Future<void> _startProcess() async {
    try {
      final p = await Process.start('timeout', [
        '900',
        'gst-launch-1.0',
        '-q',
        'rtspsrc',
        'location=$rtspUrl',
        'latency=100',
        'protocols=tcp',
        '!',
        'application/x-rtp,media=audio',
        '!',
        'rtppcmudepay',
        '!',
        'mulawdec',
        '!',
        'audioconvert',
        '!',
        'audioresample',
        '!',
        'pulsesink',
        'server=unix:/run/user/1000/pulse/native',
      ]);
      if (!_wanted) {
        p.kill();
        return;
      }
      _process = p;
      debugPrint('[door audio] playing');
      p.stdout.drain<void>();
      p.stderr.transform(utf8.decoder).listen((line) => debugPrint('[door audio] $line'));
      unawaited(
        p.exitCode.then((code) {
          if (_process == p) _process = null;
          if (_wanted) {
            debugPrint('[door audio] player exited ($code), restarting');
            _respawn = Timer(const Duration(seconds: 2), _spawn);
          }
        }),
      );
    } catch (e) {
      debugPrint('[door audio] could not start: $e');
      if (_wanted) _respawn = Timer(const Duration(seconds: 5), _spawn);
    }
  }
}
