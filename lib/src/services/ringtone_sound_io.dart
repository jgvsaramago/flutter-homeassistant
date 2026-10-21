import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One playing tone: [done] completes when it ends or is [stop]ped.
class RingtoneSound {
  RingtoneSound._(this._process) : done = _process.exitCode.then((_) {});

  final Process _process;
  final Future<void> done;

  void stop() => _process.kill();
}

final _cached = <String, Future<File>>{};

/// The asset written out once to a temp file, for gstreamer to read.
Future<File> _file(String id, Future<ByteData> Function() load) => _cached.putIfAbsent(id, () async {
  final dir = await Directory('${Directory.systemTemp.path}/kiosk-ringtones').create(recursive: true);
  // Custom ids carry a file name ("custom:Toque da avó.wav").
  final f = File('${dir.path}/${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_${id.hashCode.toUnsigned(32)}.wav');
  final data = await load();
  await f.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
  return f;
});

/// Plays ringtone [id] once at [volume] (0-1) through PulseAudio — the same
/// route as the door's sound, which follows the HDMI monitor. A separate
/// `gst-launch-1.0` process, as for the door audio, so a failure can't
/// touch the app. Null when it couldn't start (no gstreamer off the Pi).
Future<RingtoneSound?> playRingtone(String id, Future<ByteData> Function() load, double volume) async {
  try {
    final file = await _file(id, load);
    final p = await Process.start('timeout', [
      '120',
      'gst-launch-1.0',
      '-q',
      'filesrc',
      'location=${file.path}',
      '!',
      'wavparse',
      '!',
      'audioconvert',
      '!',
      'audioresample',
      '!',
      'volume',
      'volume=${volume.clamp(0.0, 1.0).toStringAsFixed(3)}',
      '!',
      'pulsesink',
      'server=unix:/run/user/1000/pulse/native',
    ]);
    p.stdout.drain<void>();
    p.stderr.transform(utf8.decoder).listen((line) => debugPrint('[ringtone] $line'));
    return RingtoneSound._(p);
  } catch (e) {
    debugPrint('[ringtone] could not play $id: $e');
    return null;
  }
}
