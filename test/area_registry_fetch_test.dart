import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_homeassistant/src/ha_client/ha_connection_config.dart';
import 'package:flutter_homeassistant/src/ha_client/ha_websocket_client.dart';
import 'package:flutter_homeassistant/src/models/ha_entity.dart';
import 'package:flutter_homeassistant/src/providers/ha_providers.dart';

class _FakeEntitiesNotifier extends EntitiesNotifier {
  _FakeEntitiesNotifier(this.data);
  final Map<String, HaEntity> data;

  @override
  Future<Map<String, HaEntity>> build() async => data;
}

class _FakeHaClient extends HaWebSocketClient {
  int registryFetchCount = 0;

  @override
  Future<Map<String, String>> getAreaByEntityId() async {
    registryFetchCount++;
    return const {};
  }
}

HaEntity _entity(String entityId) {
  final now = DateTime.now();
  return HaEntity(entityId: entityId, state: 'on', attributes: const {}, lastChanged: now, lastUpdated: now);
}

void main() {
  test('does not re-fetch the area registry on every entity state update', () async {
    final fakeClient = _FakeHaClient();
    final data = {'light.kitchen': _entity('light.kitchen')};

    final container = ProviderContainer(
      overrides: [
        haWebSocketClientProvider.overrideWithValue(fakeClient),
        connectionConfigProvider.overrideWith(
          (ref) => const HaConnectionConfig(baseUrl: 'http://example.local:8123', accessToken: 'token'),
        ),
        entitiesProvider.overrideWith(() => _FakeEntitiesNotifier(data)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(areaByEntityIdProvider.future);
    expect(fakeClient.registryFetchCount, 1);

    // Simulate a burst of `state_changed` events, exactly like a live HA
    // instance with active sensors would produce continuously.
    final notifier = container.read(entitiesProvider.notifier);
    for (var i = 0; i < 5; i++) {
      notifier.state = AsyncData({...data, 'sensor.temp_$i': _entity('sensor.temp_$i')});
      await Future<void>.delayed(Duration.zero);
    }

    // The registry fetch should only ever happen once per connection, no
    // matter how many entity updates stream in afterward.
    expect(fakeClient.registryFetchCount, 1);
  });
}
