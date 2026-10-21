import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ringtone_sound.dart';

/// One of the doorbell tones in assets/ringtones (see
/// tool/make_ringtones.py).
class Ringtone {
  const Ringtone(this.id, this.name, this.description);

  final String id;
  final String name;
  final String description;
}

const ringtones = [
  Ringtone('dingdong', 'Ding-dong', 'Campainha clássica de dois tons'),
  Ringtone('westminster', 'Westminster', 'Carrilhão de quatro notas'),
  Ringtone('tres_tons', 'Três tons', 'Acorde ascendente, curto'),
  Ringtone('carrilhao', 'Carrilhão', 'Sinos em cascata'),
  Ringtone('marimba', 'Marimba', 'Notas de madeira, alegre'),
  Ringtone('suave', 'Suave', 'Dois tons calmos'),
  Ringtone('digital', 'Digital', 'Bip de intercomunicador'),
];

/// The tone chosen and its volume (0-100), kept on this screen.
typedef RingerSettings = ({String ringtone, int volume});

/// Rings this screen's speakers when someone presses the doorbell, and
/// plays the tones for Definições' chooser.
///
/// A ring repeats the chosen tone until the call stops ringing (answered,
/// here or on the indoor station, or the visitor gave up) — [stop] — or for
/// [_maxRing] at most.
class DoorbellRinger {
  DoorbellRinger._();

  static final instance = DoorbellRinger._();

  static const _keyTone = 'doorbell_ringtone';
  static const _keyVolume = 'doorbell_volume';
  static const _maxRing = Duration(seconds: 30);
  static const _gap = Duration(milliseconds: 1200);

  final settings = ValueNotifier<RingerSettings>((ringtone: ringtones.first.id, volume: 70));

  /// The tone being previewed from Definições, if any.
  final previewing = ValueNotifier<String?>(null);

  RingtoneSound? _sound;
  int _run = 0;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tone = prefs.getString(_keyTone);
      settings.value = (
        ringtone: ringtones.any((r) => r.id == tone) ? tone! : settings.value.ringtone,
        volume: (prefs.getInt(_keyVolume) ?? settings.value.volume).clamp(0, 100),
      );
    } catch (e) {
      debugPrint('[ringtone] could not read the settings: $e');
    }
  }

  Future<void> choose({String? ringtone, int? volume}) async {
    settings.value = (ringtone: ringtone ?? settings.value.ringtone, volume: volume ?? settings.value.volume);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTone, settings.value.ringtone);
      await prefs.setInt(_keyVolume, settings.value.volume);
    } catch (e) {
      debugPrint('[ringtone] could not save the settings: $e');
    }
  }

  /// The slider's 0-100 as gain: squared, so the low half of the slider
  /// isn't all "loud" to the ear.
  double _gain(int volume) => (volume / 100) * (volume / 100);

  Future<RingtoneSound?> _play(String id, int volume) {
    _sound?.stop();
    return playRingtone(id, () => rootBundle.load('assets/ringtones/$id.wav'), _gain(volume)).then((s) => _sound = s);
  }

  /// Someone rang: the chosen tone over and over until [stop]. [afterWake]
  /// waits for a monitor that was in standby, whose speakers are silent
  /// until it's back on.
  Future<void> ring({bool afterWake = false}) async {
    final run = ++_run;
    previewing.value = null;
    final until = DateTime.now().add(_maxRing);
    if (afterWake) await Future<void>.delayed(const Duration(milliseconds: 1500));
    while (run == _run && DateTime.now().isBefore(until)) {
      final s = await _play(settings.value.ringtone, settings.value.volume);
      if (s == null) return;
      await s.done;
      if (run != _run) return;
      await Future<void>.delayed(_gap);
    }
  }

  /// Plays [id] once at the current volume; again while it's playing stops it.
  Future<void> preview(String id) async {
    final run = ++_run;
    if (previewing.value == id) {
      stop();
      return;
    }
    previewing.value = id;
    final s = await _play(id, settings.value.volume);
    if (s == null) {
      if (run == _run) previewing.value = null;
      return;
    }
    await s.done;
    if (run == _run) previewing.value = null;
  }

  void stop() {
    _run++;
    _sound?.stop();
    _sound = null;
    previewing.value = null;
  }
}
