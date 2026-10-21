import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ha_client/ha_config_flow.dart';
import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import '../../utils/optimistic.dart';
import 'pt_dates.dart';

/// The units an item's quantity can be in — the design's unit chips. Keys
/// are what's matched back out of a saved description.
const todoUnits = <String, (String one, String many)>{
  'un': ('un.', 'un.'),
  'pacote': ('pacote', 'pacotes'),
  'kg': ('kg', 'kg'),
  'g': ('g', 'g'),
  'L': ('L', 'L'),
  'duzia': ('dúzia', 'dúzias'),
};

/// Steps for the −/+ buttons: grams move in 50s, kilos in halves.
double todoUnitStep(String unit) => switch (unit) {
  'g' => 50,
  'kg' => 0.5,
  _ => 1,
};

String _num(double q) => q == q.roundToDouble() ? q.toInt().toString() : ptDec(q);

String todoQtyText(double qty, String unit) {
  if (qty <= 0) return '';
  final u = todoUnits[unit] ?? todoUnits['un']!;
  return '${_num(qty)} ${qty > 1 ? u.$2 : u.$1}';
}

/// One item on a `todo.*` list. HA items only have a summary and a free
/// description, so quantity, unit and note are kept in the description as
/// "6 pacotes · meio-gordo" — readable as-is in HA's own to-do card, and
/// parsed back here.
class TodoItem {
  const TodoItem({required this.uid, required this.name, required this.done, this.qty = 0, this.unit = 'un', this.note = ''});

  final String uid;
  final String name;
  final bool done;
  final double qty;
  final String unit;
  final String note;

  String get detail => [todoQtyText(qty, unit), note].where((s) => s.isNotEmpty).join(' · ');

  static final _qtyRe = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(un\.?|pacotes?|kg|g|L|dúzias?|duzias?)(?:\s*·\s*(.*))?$', caseSensitive: false);

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final description = (json['description'] as String? ?? '').trim();
    var qty = 0.0, unit = 'un', note = description;
    final m = _qtyRe.firstMatch(description);
    if (m != null) {
      qty = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
      final u = m.group(2)!.toLowerCase();
      unit = u.startsWith('un')
          ? 'un'
          : u.startsWith('pacote')
          ? 'pacote'
          : u.startsWith('d')
          ? 'duzia'
          : (u == 'l' ? 'L' : u);
      note = m.group(3)?.trim() ?? '';
    }
    return TodoItem(
      uid: json['uid'] as String? ?? '',
      name: (json['summary'] as String? ?? '').trim(),
      done: json['status'] == 'completed',
      qty: qty,
      unit: unit,
      note: note,
    );
  }
}

/// Icon keys a list can carry (the "Nova lista" picker).
const todoListIcons = ['list', 'cart', 'pill', 'home', 'gift'];

class TodoListInfo {
  const TodoListInfo({required this.entityId, required this.name, required this.pending, required this.icon});

  final String entityId;
  final String name;

  /// HA's own count of not-yet-done items (the entity's state).
  final int pending;
  final String icon;
}

String _guessIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('compra') || n.contains('shop') || n.contains('mercado') || n.contains('super')) return 'cart';
  if (n.contains('farm') || n.contains('medic') || n.contains('saúde')) return 'pill';
  if (n.contains('present') || n.contains('prenda') || n.contains('gift')) return 'gift';
  if (n.contains('casa') || n.contains('arranjo') || n.contains('obra') || n.contains('home')) return 'home';
  return 'list';
}

/// Per-list icon choices, saved by the kiosk itself in the shared settings
/// store (`todo_list_icons`: entity id → icon key).
final todoListIconsProvider = StateProvider<Map<String, String>>((ref) => const {});

final savedTodoListIconsProvider = FutureProvider<Map<String, String>>((ref) async {
  await haReady(ref);
  final raw = await ref.read(haWebSocketClientProvider).getSettings('todo_list_icons');
  if (raw is! Map) return const {};
  return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
});

/// Every available `todo.*` list, the shopping list first.
final todoListsProvider = Provider<List<TodoListInfo>>((ref) {
  final icons = ref.watch(todoListIconsProvider);
  final raw = ref.watch(
    entitiesProvider.select((async) {
      final entities = async.valueOrNull ?? const <String, HaEntity>{};
      return [
        for (final e in entities.values)
          if (e.domain == 'todo' && e.state != 'unavailable') '${e.entityId}\u0001${e.friendlyName.trim()}\u0001${e.state}',
      ].join('\u0000');
    }),
  );
  if (raw.isEmpty) return const [];
  final lists = [
    for (final line in raw.split('\u0000'))
      if (line.split('\u0001') case [final id, final name, final state])
        TodoListInfo(entityId: id, name: name, pending: int.tryParse(state) ?? 0, icon: icons[id] ?? _guessIcon(name)),
  ];
  lists.sort((a, b) {
    final ac = a.icon == 'cart' ? 0 : 1, bc = b.icon == 'cart' ? 0 : 1;
    return ac != bc ? ac - bc : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return lists;
});

/// The list the Início "Compras" card shows: the first shopping-cart list.
final shoppingListProvider = Provider<TodoListInfo?>((ref) {
  final lists = ref.watch(todoListsProvider);
  for (final l in lists) {
    if (l.icon == 'cart') return l;
  }
  return lists.isEmpty ? null : lists.first;
});

/// One list's items as HA has them. Refetches whenever the list entity
/// itself changes — HA bumps its state on every add or completion, from
/// this kiosk or anywhere else — and after each of this screen's own
/// changes (a rename doesn't change the entity).
final _todoFetchProvider = FutureProvider.family<List<TodoItem>, String>((ref, entityId) async {
  ref.watch(entitiesProvider.select((async) => async.valueOrNull?[entityId]?.lastUpdated));
  await haReady(ref);
  final raw = await ref.read(haWebSocketClientProvider).getTodoItems(entityId);
  final items = raw.map(TodoItem.fromJson).where((i) => i.name.isNotEmpty).toList();
  ref.read(_todoOverlayProvider.notifier).fetched(entityId, items);
  return items;
});

/// This screen's to-do changes HA hasn't confirmed yet, per list.
class _TodoOverlay extends Notifier<int> {
  final _real = <String, List<TodoItem>>{};

  late final layer = OptimisticLayer<List<TodoItem>>(
    real: (id) => _real[id],
    onChanged: () => state++,
    notConfirmed: 'O Home Assistant não confirmou a alteração à lista',
  );

  @override
  int build() => 0;

  void fetched(String entityId, List<TodoItem> items) {
    _real[entityId] = items;
    if (layer.settle()) state++;
  }

  List<TodoItem> real(String entityId) => _real[entityId] ?? const [];
}

final _todoOverlayProvider = NotifierProvider<_TodoOverlay, int>(_TodoOverlay.new);

/// One list's items as the screen shows them: HA's, with this screen's
/// pending changes on top.
final todoItemsProvider = Provider.family<AsyncValue<List<TodoItem>>, String>((ref, entityId) {
  ref.watch(_todoOverlayProvider);
  final layer = ref.read(_todoOverlayProvider.notifier).layer;
  final fetched = ref.watch(_todoFetchProvider(entityId));
  // whenData turns a refetch's loading into one with no value; keep the
  // last items on screen until the new ones arrive.
  final items = fetched.valueOrNull;
  if (items != null) return AsyncData(layer.view(entityId, items)!);
  return fetched.whenData((items) => layer.view(entityId, items)!);
});

String _description(double qty, String unit, String note) => [todoQtyText(qty, unit), note.trim()].where((s) => s.isNotEmpty).join(' · ');

/// Mutations — each a plain `todo.*` service call, shown on the list at
/// once and undone if HA doesn't confirm it (see [OptimisticLayer]).
class TodoActions {
  TodoActions(this._ref);

  final Ref _ref;

  Future<void> _run(String entityId, OptimisticChange<List<TodoItem>> change, String service, Map<String, dynamic>? data) => _ref
      .read(_todoOverlayProvider.notifier)
      .layer
      .run([change], () async {
        await _ref.read(haWebSocketClientProvider).callService('todo', service, target: {'entity_id': entityId}, serviceData: data);
        _ref.invalidate(_todoFetchProvider(entityId));
      }, timeout: const Duration(seconds: 8));

  static int _named(List<TodoItem> items, String name) => items.where((i) => !i.done && i.name.toLowerCase() == name.toLowerCase()).length;

  Future<void> add(String entityId, {required String name, double qty = 0, String unit = 'un', String note = ''}) {
    final description = _description(qty, unit, note);
    final before = _named(_ref.read(_todoOverlayProvider.notifier).real(entityId), name);
    final temp = TodoItem(uid: 'pending:${DateTime.now().microsecondsSinceEpoch}', name: name, done: false, qty: qty, unit: unit, note: note.trim());
    return _run(
      entityId,
      OptimisticChange(entityId, slot: temp.uid, patch: (items) => [...items, temp], confirmed: (items) => _named(items, name) > before),
      'add_item',
      {'item': name, if (description.isNotEmpty) 'description': description},
    );
  }

  Future<void> update(String entityId, TodoItem item, {String? name, double? qty, String? unit, String? note, bool? done}) {
    if (item.uid.startsWith('pending:')) return Future.value(); // not in HA yet
    final description = _description(qty ?? item.qty, unit ?? item.unit, note ?? item.note);
    final changesDetail = qty != null || unit != null || note != null;
    final want = TodoItem(
      uid: item.uid,
      name: name ?? item.name,
      done: done ?? item.done,
      qty: qty ?? item.qty,
      unit: unit ?? item.unit,
      note: (note ?? item.note).trim(),
    );
    bool matches(TodoItem i) => i.name == want.name && i.done == want.done && i.detail == want.detail;
    return _run(
      entityId,
      OptimisticChange(
        entityId,
        slot: item.uid,
        patch: (items) => [for (final i in items) i.uid == item.uid ? want : i],
        // Gone altogether (removed elsewhere) also ends it.
        confirmed: (items) => !items.any((i) => i.uid == item.uid && !matches(i)),
      ),
      'update_item',
      {
        'item': item.uid,
        if (name != null && name != item.name) 'rename': name,
        if (done != null) 'status': done ? 'completed' : 'needs_action',
        if (changesDetail) 'description': description,
      },
    );
  }

  Future<void> remove(String entityId, TodoItem item) {
    if (item.uid.startsWith('pending:')) return Future.value();
    return _run(
    entityId,
    OptimisticChange(
      entityId,
      slot: item.uid,
      patch: (items) => items.where((i) => i.uid != item.uid).toList(),
      confirmed: (items) => !items.any((i) => i.uid == item.uid),
    ),
    'remove_item',
    {'item': item.uid},
  );
  }

  Future<void> clearDone(String entityId) => _run(
    entityId,
    OptimisticChange(
      entityId,
      slot: 'clear',
      patch: (items) => items.where((i) => !i.done).toList(),
      confirmed: (items) => !items.any((i) => i.done),
    ),
    'remove_completed_items',
    null,
  );
}

final todoActionsProvider = Provider<TodoActions>((ref) => TodoActions(ref));

/// Creates a new Local To-do list and remembers its icon once HA reports
/// the new entity.
Future<void> createTodoList(WidgetRef ref, String name, String icon) async {
  final config = ref.read(connectionConfigProvider);
  if (config == null) throw StateError('Sem ligação ao Home Assistant');
  final before = ref.read(todoListsProvider).map((l) => l.entityId).toSet();
  await createLocalTodoList(config, name);
  // The entity shows up a moment after the flow finishes; poll briefly so
  // the chosen icon lands on the right list.
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final added = ref.read(todoListsProvider).where((l) => !before.contains(l.entityId)).toList();
    if (added.isNotEmpty) {
      final next = {...ref.read(todoListIconsProvider), added.first.entityId: icon};
      ref.read(todoListIconsProvider.notifier).state = next;
      await ref.read(haWebSocketClientProvider).setSettings('todo_list_icons', next);
      return;
    }
  }
}
