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

/// Low-latency pipeline for the door's **1080p H.265 main stream** (channel 101,
/// auth disabled).
///
/// The Pi 5 has no hardware H.264 decoder, but it *does* have a hardware HEVC
/// decoder (`v4l2slh265dec`). At 1080p that decoder outputs frames as a
/// `video/x-raw(memory:DMABuf)` (DRM-format NV12 with the Broadcom SAND
/// modifier) — exactly the zero-copy DMA-buf that flutter-pi's GL renderer can
/// import directly. So we feed the decoder straight into the appsink with **no**
/// `videoconvert` (which can't consume a DMA-buf and would force a slow
/// system-memory copy, breaking the zero-copy upload). Verified end-to-end with
/// `gst-launch` on the device.
///
/// (The door's sub-stream, channel 102, is left as H.264 because the
/// neighbours' indoor station pulls it and can't decode H.265 — see project
/// notes. H.264 has no hardware decode path on the Pi 5, so the sub-stream is
/// not used for live video here.)
String _pipeline(String rtspUrl) =>
    'rtspsrc location=$rtspUrl latency=100 protocols=tcp drop-on-latency=true '
    '! rtph265depay ! h265parse ! v4l2slh265dec ! appsink name="sink"';

/// Live door-camera view. Plays the 1080p H.265 main stream; while it connects
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
