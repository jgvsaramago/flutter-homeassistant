import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ha_client/ha_websocket_client.dart';
import '../../providers/ha_providers.dart';
import 'pt_dates.dart';

enum MealType {
  pa('Pequeno-almoço', 'PEQUENO-ALMOÇO', 8 * 60),
  almoco('Almoço', 'ALMOÇO', 13 * 60),
  jantar('Jantar', 'JANTAR', 20 * 60);

  const MealType(this.label, this.caps, this.defaultMinutes);

  final String label;
  final String caps;
  final int defaultMinutes;
}

/// Where a meal happens — drives the dot colour in the week grid.
enum MealPlace {
  casa('Em casa'),
  fora('Fora'),
  encomenda('Encomenda');

  const MealPlace(this.label);

  final String label;
}

class Meal {
  const Meal({required this.dish, this.place = MealPlace.casa, required this.time, this.note = ''});

  final String dish;
  final MealPlace place;

  /// "HH:MM"
  final String time;
  final String note;

  Map<String, dynamic> toJson() => {'dish': dish, 'where': place.name, 'time': time, if (note.isNotEmpty) 'note': note};

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
    dish: json['dish'] as String? ?? '',
    place: MealPlace.values.firstWhere((p) => p.name == json['where'], orElse: () => MealPlace.casa),
    time: json['time'] as String? ?? '20:00',
    note: json['note'] as String? ?? '',
  );
}

String mealKey(DateTime day, MealType type) => '${PtDates.key(day)}|${type.name}';

/// The family's meal plan — one entry per day and meal, kept by the kiosk
/// in the `flutter_homeassistant` integration's shared settings store
/// (`meal_plan`), so every screen in the house sees the same week.
class MealPlanNotifier extends StateNotifier<Map<String, Meal>> {
  MealPlanNotifier(this._client) : super(const {});

  final HaWebSocketClient _client;

  static const _key = 'meal_plan';

  /// Days older than this are dropped on save, so the stored plan doesn't
  /// grow forever — still long enough to learn favourite dishes from.
  static const _keepDays = 180;

  Future<void> load() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return;
    state = {
      for (final e in raw.entries)
        if (e.value is Map) e.key.toString(): Meal.fromJson((e.value as Map).cast<String, dynamic>()),
    };
  }

  Future<void> put(DateTime day, MealType type, Meal? meal) async {
    final next = Map<String, Meal>.from(state);
    final key = mealKey(day, type);
    if (meal == null) {
      next.remove(key);
    } else {
      next[key] = meal;
    }
    final cutoff = PtDates.key(addDays(DateTime.now(), -_keepDays));
    next.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    state = next;
    await _client.setSettings(_key, {for (final e in next.entries) e.key: e.value.toJson()});
  }
}

final mealPlanProvider = StateNotifierProvider<MealPlanNotifier, Map<String, Meal>>((ref) => MealPlanNotifier(ref.watch(haWebSocketClientProvider)));

const _defaultFavorites = {
  MealType.pa: ['Torradas e fruta', 'Panquecas de aveia', 'Iogurte com granola', 'Papas de aveia', 'Ovos mexidos'],
  MealType.almoco: ['Sopa e sandes', 'Salada de atum', 'Bitoque', 'Massa com legumes', 'Frango grelhado'],
  MealType.jantar: ['Bacalhau à Brás', 'Arroz de pato', 'Massa à bolonhesa', 'Frango assado', 'Sopa de legumes', 'Salmão grelhado', 'Lasanha', 'Pizza'],
};

/// Favourite dishes for one meal: what this family actually plans most
/// often for it, topped up with the design's suggestions.
List<String> mealFavorites(Map<String, Meal> plan, MealType type, {int count = 8}) {
  final counts = <String, int>{};
  for (final e in plan.entries) {
    if (!e.key.endsWith('|${type.name}') || e.value.place != MealPlace.casa) continue;
    counts[e.value.dish] = (counts[e.value.dish] ?? 0) + 1;
  }
  final ranked = (counts.entries.where((e) => e.value > 1).toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key);
  final out = <String>[];
  for (final d in [...ranked, ..._defaultFavorites[type]!]) {
    if (!out.any((o) => o.toLowerCase() == d.toLowerCase())) out.add(d);
    if (out.length == count) break;
  }
  return out;
}
