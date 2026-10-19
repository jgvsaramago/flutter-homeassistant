import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Opt-in frame-rate logging (`FPS_LOG=1` in the launch environment): every
/// few seconds prints how many frames were drawn and how long the slowest
/// UI build and raster took, so the kiosk's real frame rate can be read
/// from `journalctl` on the Pi. Frames are only produced while something
/// animates, so read it on a screen with a running animation (Início's
/// energy flow).
void startFrameStatsLogger({Duration every = const Duration(seconds: 5)}) {
  var frames = 0, janky = 0;
  var worstBuild = Duration.zero, worstRaster = Duration.zero;
  var totalRaster = Duration.zero;
  var windowStart = DateTime.now();
  const budget = Duration(microseconds: 16667);

  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    for (final t in timings) {
      frames++;
      if (t.buildDuration > worstBuild) worstBuild = t.buildDuration;
      if (t.rasterDuration > worstRaster) worstRaster = t.rasterDuration;
      totalRaster += t.rasterDuration;
      if (t.buildDuration > budget || t.rasterDuration > budget) janky++;
    }
    final elapsed = DateTime.now().difference(windowStart);
    if (elapsed < every) return;
    final fps = frames / (elapsed.inMicroseconds / 1e6);
    String ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);
    debugPrint(
      '[fps] ${fps.toStringAsFixed(1)} fps over ${elapsed.inSeconds}s · '
      'over 16.7ms: $janky/$frames · worst build ${ms(worstBuild)}ms · '
      'worst raster ${ms(worstRaster)}ms · avg raster ${frames == 0 ? '0' : ms(totalRaster ~/ frames)}ms',
    );
    frames = 0;
    janky = 0;
    worstBuild = Duration.zero;
    worstRaster = Duration.zero;
    totalRaster = Duration.zero;
    windowStart = DateTime.now();
  });
}
