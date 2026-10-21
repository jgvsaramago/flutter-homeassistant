import 'package:flutter/material.dart';
import 'package:flutterpi_gstreamer_video_player/flutterpi_gstreamer_video_player.dart';
import 'package:video_player/video_player.dart';

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
/// Also needs our patched flutter-pi (see project notes): stock flutter-pi
/// never sends `initialized` for a live source, and can't upload 1080p
/// system-memory frames.
///
/// (The sub-stream, channel 102, is what the neighbours' indoor station pulls,
/// and it only delivers ~8 fps — so the main stream is used here.)
String _pipeline(String rtspUrl) =>
    'rtspsrc location=$rtspUrl latency=100 protocols=tcp drop-on-latency=true '
    '! rtph264depay ! h264parse ! avdec_h264 '
    '! queue leaky=downstream max-size-buffers=2 max-size-bytes=0 max-size-time=0 '
    '! videoconvert ! appsink name="sink"';

/// Live door-camera view. Plays the 1080p H.264 main stream; while it connects
/// (~1s) — or if it fails — it shows [fallback] (the snapshot view), so there's
/// always a picture rather than a spinner or black box.
Widget doorLiveVideo(String subUrl, String mainUrl, {required Widget fallback}) =>
    _DoorVideo(url: mainUrl, fallback: fallback);

class _DoorVideo extends StatefulWidget {
  const _DoorVideo({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  State<_DoorVideo> createState() => _DoorVideoState();
}

enum _VideoState { connecting, live, snapshot }

class _DoorVideoState extends State<_DoorVideo> {
  VideoPlayerController? _controller;
  _VideoState _state = _VideoState.connecting;

  @override
  void initState() {
    super.initState();
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
      if (mounted) setState(() => _state = _VideoState.live);
    } catch (e) {
      debugPrint('[door] live video unavailable ($e), showing snapshots');
      if (mounted) setState(() => _state = _VideoState.snapshot);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = _state == _VideoState.live && c != null && c.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
          )
        else
          widget.fallback,
        Positioned(top: 16, left: 16, child: _StatusChip(state: _state)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final _VideoState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      _VideoState.live => ('AO VIVO · HD', const Color(0xFF2E7D32)),
      _VideoState.connecting => ('A LIGAR…', const Color(0xB3000000)),
      _VideoState.snapshot => ('IMAGENS (vídeo indisp.)', const Color(0xCCB26A00)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}
