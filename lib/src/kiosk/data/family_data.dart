import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ha_client/ha_websocket_client.dart';
import '../../models/ha_entity.dart';
import '../../providers/calendar_entities_provider.dart';
import '../../providers/ha_providers.dart';
import '../theme/kiosk_tokens.dart';

/// One household member as configured in the HA sidebar panel ("Família"):
/// a name, a colour from the shared palette, and optionally the calendar
/// that is theirs — new events "para" this person are created there, and
/// its events are drawn in their colour.
class FamilyMemberConfig {
  const FamilyMemberConfig({required this.name, this.color, this.calendarEntityId});

  final String name;
  final String? color;
  final String? calendarEntityId;

  factory FamilyMemberConfig.fromJson(Map<String, dynamic> json) =>
      FamilyMemberConfig(name: (json['name'] as String? ?? '').trim(), color: json['color'] as String?, calendarEntityId: json['calendarEntityId'] as String?);
}

/// Reads the member list saved by the sidebar panel. Read-only from the
/// app, like every other entity mapping (see `house_mode_store.dart`).
class FamilyStore {
  FamilyStore(this._client);

  final HaWebSocketClient _client;

  static const key = 'family_members';

  Future<List<FamilyMemberConfig>> read() async {
    final raw = await _client.getSettings(key);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) => FamilyMemberConfig.fromJson(m.cast<String, dynamic>())).where((m) => m.name.isNotEmpty).toList();
  }
}

final familyStoreProvider = Provider<FamilyStore>((ref) => FamilyStore(ref.watch(haWebSocketClientProvider)));

final savedFamilyProvider = FutureProvider<List<FamilyMemberConfig>>((ref) async {
  await ref.watch(entitiesProvider.future);
  return ref.watch(familyStoreProvider).read();
});

final familyConfigProvider = StateProvider<List<FamilyMemberConfig>>((ref) => const []);

/// A resolved member, ready to draw: [id] is stable across sessions (tasks
/// are saved against it), [initial] is what goes in the round avatar.
class FamilyMember {
  const FamilyMember({required this.id, required this.name, required this.color, this.calendarEntityId});

  final String id;
  final String name;
  final KPersonColor color;
  final String? calendarEntityId;

  String get initial => name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
}

String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9à-ÿ]+'), '_').replaceAll(RegExp(r'^_|_$'), '');

/// The household as the kiosk shows it. Configured members win; with none
/// configured yet, falls back to HA's own `person.*` entities (those with a
/// known state) plus a shared "Família" member — so tasks and the
/// "Para quem" pickers work before anyone has opened the panel.
final familyMembersProvider = Provider<List<FamilyMember>>((ref) {
  final config = ref.watch(familyConfigProvider);
  if (config.isNotEmpty) {
    return [
      for (var i = 0; i < config.length; i++)
        FamilyMember(
          id: _slug(config[i].name),
          name: config[i].name,
          color: config[i].color == null ? KPersonColor.cycle[i % KPersonColor.cycle.length] : KPersonColor.fromKey(config[i].color),
          calendarEntityId: config[i].calendarEntityId,
        ),
    ];
  }
  final persons = ref.watch(_personNamesProvider);
  return [
    for (var i = 0; i < persons.length; i++) FamilyMember(id: _slug(persons[i]), name: persons[i], color: i.isEven ? KPersonColor.blue : KPersonColor.orange),
    const FamilyMember(id: 'familia', name: 'Família', color: KPersonColor.green),
  ];
});

final _personNamesProvider = Provider<List<String>>((ref) {
  final names = ref.watch(
    entitiesProvider.select((async) {
      final entities = async.valueOrNull ?? const <String, HaEntity>{};
      final list = [
        for (final e in entities.values)
          if (e.domain == 'person' && !e.isUnavailable) e.friendlyName.trim(),
      ]..sort();
      return list.join('\u0000');
    }),
  );
  return names.isEmpty ? const [] : names.split('\u0000');
});

/// One calendar the Calendário reads from, with who it belongs to: a
/// member's own calendar takes their name and colour, any other configured
/// calendar keeps its own. [holiday] calendars draw as red flag bands, the
/// way the design shows "Feriados".
class CalendarSource {
  const CalendarSource({required this.entityId, required this.name, required this.color, required this.holiday, required this.writable, this.memberId});

  final String entityId;
  final String name;
  final KPersonColor color;
  final bool holiday;
  final bool writable;
  final String? memberId;

  String get initial => name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
}

bool _looksLikeHolidays(String entityId, String name) {
  final s = '$entityId $name'.toLowerCase();
  return s.contains('holiday') || s.contains('feriado');
}

final calendarSourcesProvider = Provider<List<CalendarSource>>((ref) {
  final members = ref.watch(familyMembersProvider);
  final entries = ref.watch(calendarEntriesProvider);
  // Only names/features are read here, so select those rather than
  // rebuilding every calendar on every entity update.
  final meta = ref.watch(
    entitiesProvider.select((async) {
      final entities = async.valueOrNull ?? const <String, HaEntity>{};
      return {
        for (final e in entities.values)
          if (e.domain == 'calendar') e.entityId: '${e.friendlyName.trim()}|${(e.attributes['supported_features'] as num?)?.toInt() ?? 0}',
      }.entries.map((e) => '${e.key}=${e.value}').join('\n');
    }),
  );
  final info = <String, ({String name, int features})>{};
  for (final line in meta.split('\n')) {
    final eq = line.indexOf('=');
    if (eq < 0) continue;
    final bar = line.lastIndexOf('|');
    info[line.substring(0, eq)] = (name: line.substring(eq + 1, bar), features: int.tryParse(line.substring(bar + 1)) ?? 0);
  }

  final sources = <CalendarSource>[];
  final seen = <String>{};
  for (final m in members) {
    final id = m.calendarEntityId;
    if (id == null || id.isEmpty || !seen.add(id)) continue;
    sources.add(CalendarSource(entityId: id, name: m.name, color: m.color, holiday: false, writable: ((info[id]?.features ?? 0) & 1) == 1, memberId: m.id));
  }
  for (final entry in entries) {
    final id = entry.entityId;
    if (!seen.add(id)) continue;
    final name = info[id]?.name ?? id.split('.').last;
    final holiday = _looksLikeHolidays(id, name);
    sources.add(
      CalendarSource(
        entityId: id,
        name: holiday ? 'Feriados' : name,
        color: holiday ? KPersonColor.red : KPersonColor.fromKey(entry.color.name),
        holiday: holiday,
        writable: !holiday && ((info[id]?.features ?? 0) & 1) == 1,
      ),
    );
  }
  return sources;
});
