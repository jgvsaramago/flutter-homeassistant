import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_homeassistant/src/ha_client/ha_connection_config.dart';
import 'package:flutter_homeassistant/src/ha_client/ha_websocket_client.dart';
import 'package:flutter_homeassistant/src/models/ha_entity.dart';
import 'package:flutter_homeassistant/src/providers/ha_providers.dart';

class _FakeClient extends HaWebSocketClient {
  final _controller = StreamController<HaEntity>.broadcast();

  @override
  Stream<HaEntity> get entityUpdates => _controller.stream;

  @override
  Future<void> connect(HaConnectionConfig config) async {}

  @override
  Future<void> subscribeToStateChanges() async {}

  @override
  Future<List<HaEntity>> getStates() async => [];

  void push(HaEntity entity) => _controller.add(entity);

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

HaEntity _entity(String entityId) {
  final now = DateTime.now();
  return HaEntity(entityId: entityId, state: 'on', attributes: const {}, lastChanged: now, lastUpdated: now);
}

void main() {
  test('batches a burst of entity updates into a single state change', () async {
    final fakeClient = _FakeClient();
    final container = ProviderContainer(
      overrides: [
        haWebSocketClientProvider.overrideWithValue(fakeClient),
        connectionConfigProvider.overrideWith(
          (ref) => const HaConnectionConfig(baseUrl: 'http://example.local:8123', accessToken: 'token'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(entitiesProvider.future);

    var updateCount = 0;
    container.listen(entitiesProvider, (previous, next) => updateCount++);

    // A burst of 20 updates, matching what a large, busy HA instance
    // (thousands of entities) sends within a fraction of a second.
    for (var i = 0; i < 20; i++) {
      fakeClient.push(_entity('sensor.temp_$i'));
    }

    // Nothing flushed yet — the batching window hasn't elapsed.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(updateCount, 0);

    // Past the flush window: exactly one coalesced update, not 20 separate
    // ones (each of which would have triggered every screen watching
    // entitiesProvider to re-group/re-sort/rebuild).
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(updateCount, 1);

    final data = container.read(entitiesProvider).value!;
    expect(data.length, 20);
  });
}
