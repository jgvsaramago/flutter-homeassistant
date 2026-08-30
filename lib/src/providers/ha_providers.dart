import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ha_client/ha_connection_config.dart';
import '../ha_client/ha_credentials_store.dart';
import '../ha_client/ha_websocket_client.dart';
import '../models/ha_entity.dart';
import '../services/screen_power_controller.dart';

final haCredentialsStoreProvider = Provider<HaCredentialsStore>((ref) => HaCredentialsStore());

/// Single long-lived websocket client shared by the whole app.
final haWebSocketClientProvider = Provider<HaWebSocketClient>((ref) {
  final client = HaWebSocketClient();
  ref.onDispose(client.dispose);
  return client;
});

/// Credentials persisted from a previous session, read once at startup.
final savedConnectionConfigProvider = FutureProvider<HaConnectionConfig?>((ref) {
  return ref.watch(haCredentialsStoreProvider).read();
});

/// The connection currently in use. Null means no `--ha-url`/`--ha-token`
/// was ever passed on the launch command (see `main.dart`) — [entitiesProvider]
/// just resolves to an empty entity set in that case rather than connecting.
/// Set this to trigger [entitiesProvider] to (re)connect the shared client.
final connectionConfigProvider = StateProvider<HaConnectionConfig?>((ref) => null);

final haConnectionStateProvider = StreamProvider<HaConnectionState>((ref) {
  return ref.watch(haWebSocketClientProvider).connectionState;
});

/// How often accumulated `state_changed` events get flushed into [state] at
/// most. On a small HA instance this is invisible; on a large one (found by
/// testing against a real instance with ~3200 entities) pushing a brand new
/// state on every single event meant every screen watching [entitiesProvider]
/// — grouping, sorting, and rebuilding its whole widget tree — dozens of
/// times per second, which visibly outran the dev build's paint pipeline and
/// looked like the page randomly going blank. Entities still feel live at
/// this batching interval; nothing but raw update frequency changes.
const _entityUpdateFlushInterval = Duration(milliseconds: 200);

/// Backoff schedule for reconnect attempts after the connection drops —
/// capped at 30s rather than growing unbounded, so a long HA outage still
/// gets noticed and recovered from within half a minute of it coming back,
/// without hammering it while it's down.
const _reconnectBackoff = [
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 20),
  Duration(seconds: 30),
];

/// All known entities, keyed by entity_id, kept live via `state_changed`
/// subscription. Depends on [connectionConfigProvider]; reconnects whenever
/// it changes.
///
/// Also reconnects on its own whenever the *same* config's connection drops
/// mid-session (an HA restart, a network blip) — without this, a dropped
/// websocket left the whole dashboard frozen on its last snapshot forever,
/// since nothing was ever watching for the disconnect and retrying.
class EntitiesNotifier extends AsyncNotifier<Map<String, HaEntity>> {
  Timer? _flushTimer;
  final Map<String, HaEntity> _pendingUpdates = {};
  StreamSubscription<HaConnectionState>? _connectionSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _disposed = false;

  @override
  Future<Map<String, HaEntity>> build() async {
    final config = ref.watch(connectionConfigProvider);
    if (config == null) return const {};

    final client = ref.read(haWebSocketClientProvider);
    final initial = await _connectAndFetch(client, config);

    final entityUpdatesSub = client.entityUpdates.listen(_bufferUpdate);
    _connectionSubscription = client.connectionState.listen((s) => _onConnectionStateChanged(s, client, config));
    ScreenPowerController.instance.isOn.addListener(_onScreenPowerChanged);

    ref.onDispose(() {
      _disposed = true;
      entityUpdatesSub.cancel();
      _connectionSubscription?.cancel();
      _reconnectTimer?.cancel();
      _flushTimer?.cancel();
      ScreenPowerController.instance.isOn.removeListener(_onScreenPowerChanged);
    });

    return initial;
  }

  /// The full "become live" sequence: connect, subscribe, fetch a fresh
  /// snapshot. Used for the initial connect and for every reconnect, so a
  /// resumed connection can never leave [state] stuck on a stale snapshot —
  /// state changes missed while disconnected are exactly why this re-fetches
  /// everything rather than trying to resume from where it left off.
  Future<Map<String, HaEntity>> _connectAndFetch(HaWebSocketClient client, HaConnectionConfig config) async {
    await client.connect(config);
    await client.subscribeToStateChanges();
    final states = await client.getStates();
    return {for (final entity in states) entity.entityId: entity};
  }

  void _onConnectionStateChanged(HaConnectionState connState, HaWebSocketClient client, HaConnectionConfig config) {
    if (connState == HaConnectionState.connected) {
      _reconnectAttempt = 0;
    } else if (connState == HaConnectionState.disconnected || connState == HaConnectionState.error) {
      _scheduleReconnect(client, config);
    }
  }

  void _scheduleReconnect(HaWebSocketClient client, HaConnectionConfig config) {
    // Already have one pending — a disconnect and a follow-up error for the
    // same drop can both reach here; only the first should schedule.
    if (_disposed || _reconnectTimer != null) return;
    final delay = _reconnectBackoff[_reconnectAttempt.clamp(0, _reconnectBackoff.length - 1)];
    _reconnectAttempt++;
    debugPrint('[ha websocket] reconnecting in ${delay.inSeconds}s...');
    _reconnectTimer = Timer(delay, () => _reconnect(client, config));
  }

  Future<void> _reconnect(HaWebSocketClient client, HaConnectionConfig config) async {
    _reconnectTimer = null;
    if (_disposed) return;
    try {
      final fresh = await _connectAndFetch(client, config);
      if (_disposed) return;
      // Whatever was buffered belongs to the dead connection's session —
      // the fresh snapshot above already reflects everything current.
      _pendingUpdates.clear();
      state = AsyncData(fresh);
    } catch (e) {
      debugPrint('[ha websocket] reconnect attempt failed: $e');
      _scheduleReconnect(client, config);
    }
  }

  void _bufferUpdate(HaEntity entity) {
    _pendingUpdates[entity.entityId] = entity;
    // While the screen is off nothing on it is visible, so there's no point
    // paying for the rebuild/layout/paint this flush causes across every
    // dashboard widget watching this provider — just keep accumulating in
    // memory and catch up in one shot in `_onScreenPowerChanged` once it's
    // actually worth being live again. A busy HA instance can otherwise
    // flush 5x/second indefinitely, which was the dashboard's real idle CPU
    // cost, not the card animations.
    if (!ScreenPowerController.instance.isOn.value) return;
    _flushTimer ??= Timer(_entityUpdateFlushInterval, _flushUpdates);
  }

  void _onScreenPowerChanged() {
    if (ScreenPowerController.instance.isOn.value) _flushUpdates();
  }

  void _flushUpdates() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingUpdates.isEmpty) return;
    final current = Map<String, HaEntity>.from(state.value ?? const {})..addAll(_pendingUpdates);
    _pendingUpdates.clear();
    state = AsyncData(current);
  }
}

final entitiesProvider = AsyncNotifierProvider<EntitiesNotifier, Map<String, HaEntity>>(EntitiesNotifier.new);

/// Entities grouped by domain and sorted by friendly name within each group,
/// with domains sorted alphabetically by their display label.
final entitiesByDomainProvider = Provider<List<MapEntry<String, List<HaEntity>>>>((ref) {
  final entities = ref.watch(entitiesProvider).value ?? const {};

  final byDomain = <String, List<HaEntity>>{};
  for (final entity in entities.values) {
    byDomain.putIfAbsent(entity.domain, () => []).add(entity);
  }

  for (final list in byDomain.values) {
    list.sort((a, b) => a.friendlyName.toLowerCase().compareTo(b.friendlyName.toLowerCase()));
  }

  final entries = byDomain.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return entries;
});

/// Sorted entity ids, optionally restricted to one domain (`null` for every
/// domain) — the list `EntityIdField`'s autocomplete searches.
///
/// Cached per [domainFilter] and recomputed only when [entitiesProvider]
/// itself actually changes, unlike computing this inline in each field's own
/// `build()`: a settings screen can have well over a dozen `EntityIdField`s
/// on one page (see `EvCarsCard`), and every one of them rebuilds on every
/// keystroke into *any* field on that page (each field's `onChanged` bubbles
/// up to a `setState` on the whole card). Sorting a real HA instance's full
/// entity list — several thousand entries isn't unusual — that many times
/// per keystroke is exactly the kind of cost that reads as "the on-screen
/// keyboard feels laggy" without anything actually being wrong with the
/// keyboard itself.
final entityIdsProvider = Provider.family<List<String>, String?>((ref, domainFilter) {
  final entities = ref.watch(entitiesProvider).value ?? const {};
  return entities.keys.where((id) => domainFilter == null || id.startsWith('$domainFilter.')).toList()..sort();
});

/// entity_id -> area name, resolved once per connection via the entity /
/// device / area registries.
///
/// Watches [connectionConfigProvider] explicitly (changes only on
/// connect/disconnect) rather than `entitiesProvider.future` — the latter
/// is meant to only resolve once per connection too, and a test confirms it
/// doesn't actually re-fire on plain `state_changed`-driven state updates,
/// but it's an easy thing to get wrong (the pattern name doesn't make that
/// guarantee obvious) so this is the more explicit, harder-to-regress
/// version of the same intent.
final areaByEntityIdProvider = FutureProvider<Map<String, String>>((ref) async {
  final config = ref.watch(connectionConfigProvider);
  if (config == null) return const {};

  await ref.read(entitiesProvider.future);
  return ref.read(haWebSocketClientProvider).getAreaByEntityId();
});

