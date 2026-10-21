import 'dart:async';

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
///  * `videoconvert` passes `avdec_h264`'s I420 straight through (I420 is in
///    the appsink's accepted list); it's only there to adapt if the stream
///    ever decodes to a format the sink doesn't take.
///
/// With [audio], the stream's G.711 µ-law track is also played through
/// PipeWire's pulse socket, which routes to whichever HDMI port the monitor
/// (and its speakers) is on. It starts muted; the element named `volume` is
/// what `VideoPlayerController.setVolume` drives (via our flutter-pi patch).
/// The audio branch has its own leaky queue so a stalled sound server can't
/// block the video.
///
/// Also needs our patched flutter-pi (see project notes): stock flutter-pi
/// never sends `initialized` for a live source, can't upload 1080p
/// system-memory frames, and ignores `setVolume`.
///
/// (The sub-stream, channel 102, is what the neighbours' indoor station pulls,
/// and it only delivers ~8 fps — so the main stream is used here.)
String _pipeline(String rtspUrl, {required bool audio}) {
  const video =
      '! rtph264depay ! h264parse ! avdec_h264 '
      '! queue leaky=downstream max-size-buffers=2 max-size-bytes=0 max-size-time=0 '
      '! videoconvert ! appsink name="sink"';
  if (!audio) return 'rtspsrc location=$rtspUrl latency=100 protocols=tcp drop-on-latency=true $video';
  return 'rtspsrc name=rtsp location=$rtspUrl latency=100 protocols=tcp drop-on-latency=true '
      'rtsp. ! application/x-rtp,media=video $video '
      'rtsp. ! application/x-rtp,media=audio ! rtppcmudepay ! mulawdec '
      '! queue leaky=downstream max-size-time=300000000 max-size-buffers=0 max-size-bytes=0 '
      '! audioconvert ! audioresample ! volume name=volume volume=0 '
      '! pulsesink server=unix:/run/user/1000/pulse/native';
}

/// Live door-camera view. Plays the 1080p H.264 main stream; while it connects
/// (~1s) — or if it fails — it shows [fallback] (the snapshot view), so there's
/// always a picture rather than a spinner or black box. [status] reports which
/// of those is on screen, for the intercom modal's header badge; [audio] says
/// whether the door's sound should be playing (in a call) or muted.
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
    widget.audio.addListener(_applyAudio);
    _start();
  }

  void _applyAudio() => _controller?.setVolume(widget.audio.value ? 1 : 0);

  /// Starts one pipeline and waits (bounded) for it to report initialized.
  /// The backend has hung before, so never wait on it forever.
  Future<VideoPlayerController> _open({required bool audio, required Duration timeout}) async {
    final c = FlutterpiVideoPlayerController.withGstreamerPipeline(_pipeline(widget.url, audio: audio));
    _controller = c;
    // Set before initialize: video_player applies the stored volume once the
    // player is up, so the door's sound never blips on at full volume.
    await c.setVolume(widget.audio.value ? 1 : 0);
    try {
      await c.initialize().timeout(timeout);
    } catch (_) {
      _controller = null;
      unawaited(c.dispose());
      rethrow;
    }
    return c;
  }

  Future<void> _start() async {
    VideoPlayerController? c;
    // Video + audio first. If that doesn't come up (e.g. the sound server is
    // down), retry video-only: losing the sound must never cost the picture.
    try {
      c = await _open(audio: true, timeout: const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[door] live video with audio unavailable ($e), retrying video-only');
      if (!mounted) return;
      try {
        c = await _open(audio: false, timeout: const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[door] live video unavailable ($e), showing snapshots');
        if (mounted) widget.status.value = IntercomVideoStatus.snapshots;
        return;
      }
    }
    if (!mounted) return;
    await c.play();
    debugPrint('[door] live video initialized: size=${c.value.size} playing=${c.value.isPlaying}');
    if (!mounted) return;
    setState(() => _live = true);
    widget.status.value = IntercomVideoStatus.live;
  }

  @override
  void dispose() {
    widget.audio.removeListener(_applyAudio);
    // Closing the modal mid-call ends the call: start muted next time.
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
