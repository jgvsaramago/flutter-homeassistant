import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ha_client/ha_websocket_client.dart';
import '../../providers/ha_providers.dart';
import 'pt_dates.dart';

/// One household task. Repeats on [days] (0 = Monday … 6 = Sunday), or —
/// with [days] null — happens once, on [date].
class Chore {
  const Chore({required this.id, required this.title, required this.who, this.days, this.date, this.due = ''});

  final String id;
  final String title;

  /// A `FamilyMember.id`.
  final String who;
  final List<int>? days;

  /// "YYYY-MM-DD", for one-off tasks.
  final String? date;

  /// "HH:MM" deadline, or empty.
  final String due;

  bool onDay(DateTime day) => days != null ? days!.contains(day.weekday - 1) : date == PtDates.key(day);

  String get repeatLabel {
    final d = days;
    if (d == null) return 'Só neste dia';
    if (d.length == 7) return 'Todos os dias';
    if (d.join(',') == '0,1,2,3,4') return 'Dias úteis';
    return d.map((i) => PtDates.abbrLower[i]).join(' · ');
  }

  String get meta => repeatLabel + (due.isNotEmpty ? ' · até às $due' : '');

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'who': who, 'days': days, 'date': date, if (due.isNotEmpty) 'due': due};

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    who: json['who'] as String? ?? '',
    days: (json['days'] as List?)?.whereType<num>().map((n) => n.toInt()).toList(),
    date: json['date'] as String?,
    due: json['due'] as String? ?? '',
  );
}

class ChoresState {
  const ChoresState({this.chores = const [], this.done = const {}});

  final List<Chore> chores;

  /// "YYYY-MM-DD|choreId" for every completion.
  final Set<String> done;

  bool isDone(DateTime day, Chore c) => done.contains('${PtDates.key(day)}|${c.id}');

  List<Chore> forDay(DateTime day) => chores.where((c) => c.onDay(day)).toList()
    ..sort((a, b) {
      final ad = a.due.isEmpty ? '99' : a.due, bd = b.due.isEmpty ? '99' : b.due;
      return ad != bd ? ad.compareTo(bd) : a.title.compareTo(b.title);
    });
}

/// The household's tasks and which were ticked off on which day — kept by
/// the kiosk in the integration's shared settings store (`chores`), like
/// the meal plan.
class ChoresNotifier extends StateNotifier<ChoresState> {
  ChoresNotifier(this._client) : super(const ChoresState());

  final HaWebSocketClient _client;

  static const _key = 'chores';
  static const _keepDays = 60;

  Future<void> load() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return;
    state = ChoresState(
      chores: ((raw['tasks'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Chore.fromJson(m.cast<String, dynamic>()))
          .where((c) => c.id.isNotEmpty)
          .toList(),
      done: ((raw['done'] as List?) ?? const []).whereType<String>().toSet(),
    );
  }

  Future<void> _save(ChoresState next) async {
    final cutoff = PtDates.key(addDays(DateTime.now(), -_keepDays));
    final done = next.done.where((k) => k.compareTo(cutoff) >= 0).toSet();
    // Drop one-off tasks whose day has long passed, too.
    final chores = next.chores.where((c) => c.days != null || (c.date ?? '').compareTo(cutoff) >= 0).toList();
    state = ChoresState(chores: chores, done: done);
    await _client.setSettings(_key, {'tasks': chores.map((c) => c.toJson()).toList(), 'done': done.toList()..sort()});
  }

  Future<void> toggle(DateTime day, Chore c) {
    final k = '${PtDates.key(day)}|${c.id}';
    final done = Set<String>.from(state.done);
    if (!done.remove(k)) done.add(k);
    return _save(ChoresState(chores: state.chores, done: done));
  }

  Future<void> upsert(Chore c) {
    final list = [...state.chores];
    final i = list.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      list[i] = c;
    } else {
      list.add(c);
    }
    return _save(ChoresState(chores: list, done: state.done));
  }

  Future<void> remove(String id) => _save(ChoresState(chores: state.chores.where((c) => c.id != id).toList(), done: state.done));
}

final choresProvider = StateNotifierProvider<ChoresNotifier, ChoresState>((ref) => ChoresNotifier(ref.watch(haWebSocketClientProvider)));
