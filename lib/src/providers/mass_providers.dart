import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mass_client/mass_connection_config.dart';
import '../mass_client/mass_credentials_store.dart';
import '../mass_client/mass_models.dart';
import '../mass_client/mass_websocket_client.dart';
import '../services/screen_power_controller.dart';
import 'ha_providers.dart';

final massCredentialsStoreProvider = Provider<MassCredentialsStore>(
  (ref) => MassCredentialsStore(ref.watch(haWebSocketClientProvider)),
);

/// Single long-lived Music Assistant websocket client, shared app-wide —
/// same shape as `haWebSocketClientProvider`.
final massWebSocketClientProvider = Provider<MassWebSocketClient>((ref) {
  final client = MassWebSocketClient();
  ref.onDispose(client.dispose);
  return client;
});

/// Credentials persisted from a previous session, read once at startup —
/// waits for the HA connection first (this store now lives behind it, same
/// idiom as `areaByEntityIdProvider`). Note: this means Music Assistant no
/// longer starts connecting until the HA websocket connects first — see the
/// settings-migration plan's scope decision 3.
final savedMassConnectionConfigProvider = FutureProvider<MassConnectionConfig?>((ref) async {
  await ref.watch(entitiesProvider.future);
  return ref.watch(massCredentialsStoreProvider).read();
});

/// Null means no `MASS_URL`/`MASS_TOKEN` was ever given or saved — the
/// Music sheet just shows "no server configured" in that case, the same
/// treatment `entitiesProvider` gives a missing HA connection.
final massConnectionConfigProvider = StateProvider<MassConnectionConfig?>((ref) => null);

final massConnectionStateProvider = StreamProvider<MassConnectionState>((ref) {
  return ref.watch(massWebSocketClientProvider).connectionState;
});

/// All known players, kept live via `player_updated`/`player_added` events.
/// Reconnects whenever [massConnectionConfigProvider] changes.
class MassPlayersNotifier extends AsyncNotifier<Map<String, MassPlayer>> {
  StreamSubscription? _eventSub;
  final Map<String, MassPlayer> _pendingUpdates = {};

  @override
  Future<Map<String, MassPlayer>> build() async {
    final config = ref.watch(massConnectionConfigProvider);
    if (config == null) return const {};

    final client = ref.read(massWebSocketClientProvider);
    await client.connect(config);
    final players = await client.getAllPlayers();

    _eventSub = client.events.listen(_onEvent);
    ScreenPowerController.instance.isOn.addListener(_onScreenPowerChanged);

    ref.onDispose(() {
      _eventSub?.cancel();
      ScreenPowerController.instance.isOn.removeListener(_onScreenPowerChanged);
    });

    return {for (final player in players) player.playerId: player};
  }

  void _onEvent(MassEvent event) {
    if (event.event != 'player_updated' && event.event != 'player_added') return;
    final data = event.data;
    if (data is! Map) return;
    final player = MassPlayer.fromJson(data.cast<String, dynamic>());
    _pendingUpdates[player.playerId] = player;
    // While the screen is off nothing on the Now Playing card is visible, so
    // there's no point paying for the rebuild/layout/paint this causes —
    // just keep accumulating in memory and catch up in one shot in
    // `_onScreenPowerChanged` once it's actually worth being live again.
    // Mirrors `EntitiesNotifier`'s identical fix in `ha_providers.dart` (the
    // same class of invisible idle CPU cost, just for MASS instead of HA) —
    // unlike that one, there's no need for an extra flush-interval cap here
    // too: a couple of players' progress ticks are nowhere near the update
    // volume a few-thousand-entity HA instance can produce, so applying
    // every update immediately while the screen is on keeps the progress
    // bar exactly as live as it was before this change.
    if (!ScreenPowerController.instance.isOn.value) return;
    _flushUpdates();
  }

  void _onScreenPowerChanged() {
    if (ScreenPowerController.instance.isOn.value) _flushUpdates();
  }

  void _flushUpdates() {
    if (_pendingUpdates.isEmpty) return;
    final current = Map<String, MassPlayer>.from(state.value ?? const {})..addAll(_pendingUpdates);
    _pendingUpdates.clear();
    state = AsyncData(current);
  }
}

final massPlayersProvider = AsyncNotifierProvider<MassPlayersNotifier, Map<String, MassPlayer>>(MassPlayersNotifier.new);
