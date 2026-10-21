import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'door_station.dart';
import 'doorbell_history_store_stub.dart' if (dart.library.io) 'doorbell_history_store_io.dart' as store;
import 'doorbell_watcher.dart';

/// One ring of this apartment's doorbell, as this screen saw it.
class DoorbellCall {
  DoorbellCall({
    required this.id,
    required this.at,
    this.endedAt,
    this.answeredAt,
    this.answeredIndoor = false,
    this.answeredHere = false,
    this.doorOpened = false,
    this.hasPicture = false,
    this.heardAt,
    this.heardEndedAt,
  });

  factory DoorbellCall.fromJson(Map<String, dynamic> j) => DoorbellCall(
    id: j['id'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
    endedAt: j['endedAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['endedAt'] as int),
    answeredAt: j['answeredAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['answeredAt'] as int),
    answeredIndoor: j['answeredIndoor'] == true,
    answeredHere: j['answeredHere'] == true,
    doorOpened: j['doorOpened'] == true,
    hasPicture: j['hasPicture'] == true,
    heardAt: j['heardAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['heardAt'] as int),
    heardEndedAt: j['heardEndedAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['heardEndedAt'] as int),
  );

  final String id;
  final DateTime at;
  DateTime? endedAt;

  /// When the indoor station picked up, for the talk time.
  DateTime? answeredAt;

  /// Picked up on the indoor station (or Hik-Connect) — the only place a
  /// call can really be answered; this screen only listens.
  bool answeredIndoor;

  /// "Atender" was tapped on this screen (it listens in; the call itself
  /// stays with the indoor station).
  bool answeredHere;
  bool doorOpened;
  bool hasPicture;

  /// When "Atender" was tapped here, and when this screen stopped listening.
  DateTime? heardAt;
  DateTime? heardEndedAt;

  bool get ringing => endedAt == null;
  bool get missed => endedAt != null && !answeredIndoor && !answeredHere;

  /// How long the call lasted where it was answered: on the indoor station
  /// if it picked up, else how long this screen listened in.
  Duration? get talkTime {
    if (answeredIndoor) return answeredAt != null && endedAt != null ? endedAt!.difference(answeredAt!) : null;
    final from = heardAt, to = heardEndedAt ?? endedAt;
    return answeredHere && from != null && to != null && to.isAfter(from) ? to.difference(from) : null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    if (endedAt != null) 'endedAt': endedAt!.millisecondsSinceEpoch,
    if (answeredAt != null) 'answeredAt': answeredAt!.millisecondsSinceEpoch,
    'answeredIndoor': answeredIndoor,
    'answeredHere': answeredHere,
    'doorOpened': doorOpened,
    'hasPicture': hasPicture,
    if (heardAt != null) 'heardAt': heardAt!.millisecondsSinceEpoch,
    if (heardEndedAt != null) 'heardEndedAt': heardEndedAt!.millisecondsSinceEpoch,
  };
}

/// Saved files for [DoorbellHistory]: the list as JSON and one JPEG per call.
abstract class DoorbellHistoryStore {
  Future<String?> load();
  Future<void> save(String json);
  Future<void> savePicture(String id, Uint8List jpeg);
  Future<Uint8List?> loadPicture(String id);
  Future<void> deletePicture(String id);
}

/// This apartment's doorbell calls with a picture of who rang.
///
/// Neither Hikvision device lets anyone read its call log, so the screen
/// keeps its own: it follows the indoor station's call state, grabs a still
/// from the door camera the moment a ring starts, and asks the door station
/// afterwards whether the door was unlocked during the call. It only ever
/// reads from the devices — recording a call never touches the call itself.
class DoorbellHistory {
  DoorbellHistory({required this.station, required Stream<IndoorCallStatus> statuses, DoorbellHistoryStore? storage})
    : _store = storage ?? store.makeDoorbellHistoryStore() {
    _ready = _load();
    _sub = statuses.listen((s) => _ready.then((_) => _onStatus(s)));
  }

  static const _keep = 200;

  /// A ring that never saw its end (link dropped) is closed after this.
  static const _staleAfter = Duration(minutes: 3);

  /// How long after a call the door station is asked about unlocks: long
  /// enough for someone to press "open" right after hanging up.
  static const _unlockCheckAfter = Duration(seconds: 30);

  final DoorStation station;
  final DoorbellHistoryStore _store;
  late final Future<void> _ready;
  late final StreamSubscription<IndoorCallStatus> _sub;

  /// Newest first.
  final calls = ValueNotifier<List<DoorbellCall>>(const []);

  /// Missed calls nobody has looked at in the history yet.
  final unseenMissed = ValueNotifier<int>(0);

  DateTime _seenUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DoorbellCall? _current;
  final _unlocksAtRing = <String, int?>{};

  Future<void> _load() async {
    try {
      final raw = await _store.load();
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _seenUntil = DateTime.fromMillisecondsSinceEpoch(j['seenUntil'] as int? ?? 0);
      final list = [for (final c in j['calls'] as List? ?? const []) DoorbellCall.fromJson(c as Map<String, dynamic>)];
      // A call still open in the file was cut short by a restart.
      for (final c in list) {
        c.endedAt ??= c.at;
      }
      calls.value = list;
      _recount();
    } catch (e) {
      debugPrint('[doorbell history] could not load: $e');
    }
  }

  void _onStatus(IndoorCallStatus status) {
    final now = DateTime.now();
    final current = _current;
    if (current != null && now.difference(current.at) > _staleAfter && status != IndoorCallStatus.onCall) {
      _end(current, now);
    }
    switch (status) {
      case IndoorCallStatus.ringing:
        if (_current == null) _start(now);
      case IndoorCallStatus.onCall:
        final c = _current;
        if (c != null && !c.answeredIndoor) {
          c.answeredIndoor = true;
          c.answeredAt = now;
          _changed();
        }
      case IndoorCallStatus.idle:
        final c = _current;
        if (c != null) _end(c, now);
    }
  }

  void _start(DateTime now) {
    final call = DoorbellCall(id: '${now.millisecondsSinceEpoch}', at: now);
    _current = call;
    debugPrint('[doorbell history] ring at $now');
    calls.value = [call, ...calls.value];
    _trim();
    _changed();
    unawaited(_takePicture(call));
    unawaited(station.doorUnlockCount().then((n) => _unlocksAtRing[call.id] = n));
  }

  void _end(DoorbellCall call, DateTime now) {
    if (identical(_current, call)) _current = null;
    call.endedAt ??= now;
    _changed();
    Timer(_unlockCheckAfter, () => _checkUnlocked(call));
  }

  Future<void> _takePicture(DoorbellCall call) async {
    // The visitor is at the panel right now; a miss is retried a few times
    // rather than waiting for a later, emptier frame.
    for (var attempt = 0; attempt < 4; attempt++) {
      final jpeg = await station.snapshot(full: true);
      if (jpeg != null && jpeg.isNotEmpty) {
        try {
          await _store.savePicture(call.id, jpeg);
          call.hasPicture = true;
          _changed();
        } catch (e) {
          debugPrint('[doorbell history] could not save picture: $e');
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  Future<void> _checkUnlocked(DoorbellCall call) async {
    final before = _unlocksAtRing.remove(call.id);
    if (before == null || call.doorOpened) return;
    final after = await station.doorUnlockCount();
    if (after != null && after > before) {
      call.doorOpened = true;
      _changed();
    }
  }

  /// "Atender" on this screen during a ring.
  void answeredHere() {
    final c = _current;
    if (c == null || c.answeredHere) return;
    c.answeredHere = true;
    c.heardAt = DateTime.now();
    _changed();
  }

  /// This screen stopped listening (hung up, or the screen closed).
  void stoppedListening() {
    for (final c in calls.value.take(3)) {
      if (c.heardAt != null && c.heardEndedAt == null) {
        c.heardEndedAt = DateTime.now();
        _changed();
        return;
      }
    }
  }

  /// The door was opened from this screen: counts for the ringing call or
  /// one that just ended.
  void doorOpenedHere() {
    final now = DateTime.now();
    final c = _current ?? calls.value.firstOrNull;
    if (c == null || c.doorOpened) return;
    final end = c.endedAt;
    if (end != null && now.difference(end) > const Duration(minutes: 2)) return;
    c.doorOpened = true;
    _changed();
  }

  /// The history was looked at: missed calls so far no longer count as new.
  /// Returns the ids of the ones that were new until now, so this visit can
  /// still tag them.
  Set<String> markSeen() {
    final fresh = {for (final c in calls.value) if (c.missed && c.at.isAfter(_seenUntil)) c.id};
    _seenUntil = DateTime.now();
    _changed();
    return fresh;
  }

  Future<Uint8List?> picture(DoorbellCall call) => call.hasPicture ? _store.loadPicture(call.id) : Future.value();

  void _trim() {
    final list = calls.value;
    if (list.length <= _keep) return;
    for (final c in list.skip(_keep)) {
      if (c.hasPicture) unawaited(_store.deletePicture(c.id).catchError((_) {}));
    }
    calls.value = list.take(_keep).toList();
  }

  void _recount() => unseenMissed.value = calls.value.where((c) => c.missed && c.at.isAfter(_seenUntil)).length;

  void _changed() {
    calls.value = List.of(calls.value);
    _recount();
    final json = jsonEncode({
      'seenUntil': _seenUntil.millisecondsSinceEpoch,
      'calls': [for (final c in calls.value) c.toJson()],
    });
    unawaited(_store.save(json).catchError((Object e) => debugPrint('[doorbell history] could not save: $e')));
  }

  void dispose() {
    _sub.cancel();
  }
}
