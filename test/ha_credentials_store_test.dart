import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_homeassistant/src/ha_client/ha_connection_config.dart';
import 'package:flutter_homeassistant/src/ha_client/ha_credentials_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('save/read/clear round-trip', () async {
    final store = HaCredentialsStore();

    expect(await store.read(), isNull);

    const config = HaConnectionConfig(baseUrl: 'http://homeassistant.local:8123', accessToken: 'test-token');
    await store.save(config);

    final read = await store.read();
    expect(read?.baseUrl, config.baseUrl);
    expect(read?.accessToken, config.accessToken);

    await store.clear();
    expect(await store.read(), isNull);
  });
}
