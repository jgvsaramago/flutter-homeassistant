import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_data.dart' as typed_data;

import '../services/device_stats_service.dart';
import '../services/screen_brightness_service.dart';
import '../services/screen_power_controller.dart';
import '../services/system_control_service.dart';
import '../sheets/sheet_registry.dart';
import '../theme/theme_mode_controller.dart';
import 'mqtt_config.dart';
import 'mqtt_connection_status.dart';

/// The HA `select` entity's two option labels — Portuguese, matching this
/// app's copy convention, and also the wire values `_handleCommand` expects
/// back on the command topic (HA's MQTT select integration always sends the
/// exact option string chosen, never a separate machine value).
const _themeOptionDark = 'Escuro';
const _themeOptionLight = 'Claro';

const _discoveryPrefix = 'homeassistant';
const _statsInterval = Duration(seconds: 30);

/// Publishes the Pi's own vitals to Home Assistant over MQTT, and exposes
/// screen power/brightness plus shutdown/reboot as entities HA can drive
/// back — all under one HA MQTT Discovery device, so they show up grouped
/// on a single device card rather than as five unrelated entities.
class PiTelemetryPublisher {
  PiTelemetryPublisher();

  final _stats = DeviceStatsService();
  final _brightness = ScreenBrightnessService();
  final _systemControl = SystemControlService();

  MqttServerClient? _client;
  Timer? _statsTimer;
  String _baseTopic = '';
  String _availabilityTopic = '';
  VoidCallback? _unlistenScreenIsOn;
  VoidCallback? _unlistenThemeMode;

  Future<void> start(MqttConfig config) async {
    await stop();

    final hostname = Platform.localHostname;
    final deviceId = hostname.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
    final clientId = 'flutter_dashboard_$deviceId';
    _baseTopic = 'flutter_dashboard/$deviceId';
    _availabilityTopic = '$_baseTopic/status';

    final client = MqttServerClient.withPort(config.host, clientId, config.port);
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.onDisconnected = () {
      debugPrint('[mqtt] disconnected');
      MqttConnectionController.instance.status.value = MqttConnectionStatus.disconnected;
    };
    client.onAutoReconnect = () {
      debugPrint('[mqtt] connection lost, reconnecting to broker...');
      MqttConnectionController.instance.status.value = MqttConnectionStatus.connecting;
    };
    client.onAutoReconnected = () {
      debugPrint('[mqtt] reconnected successfully');
      MqttConnectionController.instance.status.value = MqttConnectionStatus.connected;
    };

    final connectMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic(_availabilityTopic)
        .withWillMessage('offline')
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain();
    if (config.username != null) {
      connectMessage.authenticateAs(config.username, config.password);
    }
    client.connectionMessage = connectMessage;

    debugPrint('[mqtt] connecting to ${config.host}:${config.port} as $clientId...');
    MqttConnectionController.instance.status.value = MqttConnectionStatus.connecting;
    try {
      await client.connect();
    } catch (e) {
      debugPrint('[mqtt] connect failed: $e');
      MqttConnectionController.instance.status.value = MqttConnectionStatus.error;
      client.disconnect();
      return;
    }
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[mqtt] connect failed: ${client.connectionStatus?.state}');
      MqttConnectionController.instance.status.value = MqttConnectionStatus.error;
      return;
    }

    _client = client;
    MqttConnectionController.instance.status.value = MqttConnectionStatus.connected;
    debugPrint('[mqtt] connected successfully to ${config.host}:${config.port}');

    _publish(_availabilityTopic, 'online', retain: true);
    _publishDiscovery(deviceId);

    client.subscribe('$_baseTopic/light/screen/set', MqttQos.atLeastOnce);
    client.subscribe('$_baseTopic/light/screen/brightness_set', MqttQos.atLeastOnce);
    client.subscribe('$_baseTopic/button/shutdown/set', MqttQos.atLeastOnce);
    client.subscribe('$_baseTopic/button/reboot/set', MqttQos.atLeastOnce);
    client.subscribe('$_baseTopic/sheet/open', MqttQos.atLeastOnce);
    client.subscribe('$_baseTopic/sheet/close', MqttQos.atLeastOnce);
    client.subscribe('$_baseTopic/select/theme/set', MqttQos.atLeastOnce);
    client.updates?.listen(_onMessage);

    void publishScreenState() {
      _publish('$_baseTopic/light/screen/state', ScreenPowerController.instance.isOn.value ? 'ON' : 'OFF', retain: true);
    }

    ScreenPowerController.instance.isOn.addListener(publishScreenState);
    _unlistenScreenIsOn = () => ScreenPowerController.instance.isOn.removeListener(publishScreenState);
    publishScreenState();
    unawaited(_publishBrightnessState());

    void publishThemeState() {
      _publish(
        '$_baseTopic/select/theme/state',
        ThemeModeController.instance.mode.value == Brightness.light ? _themeOptionLight : _themeOptionDark,
        retain: true,
      );
    }

    ThemeModeController.instance.mode.addListener(publishThemeState);
    _unlistenThemeMode = () => ThemeModeController.instance.mode.removeListener(publishThemeState);
    publishThemeState();

    await _publishStats();
    _statsTimer = Timer.periodic(_statsInterval, (_) => _publishStats());
  }

  Future<void> stop() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    _unlistenScreenIsOn?.call();
    _unlistenScreenIsOn = null;
    _unlistenThemeMode?.call();
    _unlistenThemeMode = null;
    final client = _client;
    if (client != null) {
      _publish(_availabilityTopic, 'offline', retain: true);
      client.disconnect();
      _client = null;
    }
    MqttConnectionController.instance.status.value = MqttConnectionStatus.disabled;
  }

  void _publish(String topic, String payload, {bool retain = false}) {
    final client = _client;
    if (client == null || client.connectionStatus?.state != MqttConnectionState.connected) return;
    // Not builder.addString(payload): despite the name, mqtt_client's
    // addString doesn't UTF-8 encode — it writes one raw byte per UTF-16
    // code unit for anything ≤255, which mangles any non-ASCII character
    // (the '°' in "°C" needs two UTF-8 bytes, 0xC2 0xB0, and gets emitted
    // as the single invalid byte 0xB0 instead). That's silent on our end,
    // but it breaks HA's JSON parsing of that one payload — the whole
    // discovery message it's in gets dropped, and the entity never
    // appears, while every ASCII-only payload sails through untouched.
    // Encoding to UTF-8 ourselves and appending the raw bytes sidesteps
    // addString's encoder entirely.
    final builder = MqttClientPayloadBuilder()..addBuffer(typed_data.Uint8Buffer()..addAll(utf8.encode(payload)));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: retain);
  }

  void _publishDiscovery(String deviceId) {
    final device = {
      'identifiers': [deviceId],
      'name': 'Flutter Kiosk Entrada',
      'manufacturer': 'Raspberry Pi',
      'model': 'flutter-homeassistant kiosk',
    };

    void sensor(String objectId, {required String name, String? deviceClass, String? unit, String? icon, String? stateClass}) {
      final config = {
        'name': name,
        'unique_id': '${deviceId}_$objectId',
        'state_topic': '$_baseTopic/sensor/$objectId/state',
        'availability_topic': _availabilityTopic,
        'device': device,
        if (deviceClass != null) 'device_class': deviceClass,
        if (unit != null) 'unit_of_measurement': unit,
        if (icon != null) 'icon': icon,
        if (stateClass != null) 'state_class': stateClass,
      };
      _publish('$_discoveryPrefix/sensor/$deviceId/$objectId/config', jsonEncode(config), retain: true);
    }

    void binarySensor(String objectId, {required String name, String? deviceClass, String? icon}) {
      final config = {
        'name': name,
        'unique_id': '${deviceId}_$objectId',
        'state_topic': '$_baseTopic/binary_sensor/$objectId/state',
        'payload_on': 'ON',
        'payload_off': 'OFF',
        'availability_topic': _availabilityTopic,
        'device': device,
        if (deviceClass != null) 'device_class': deviceClass,
        if (icon != null) 'icon': icon,
      };
      _publish('$_discoveryPrefix/binary_sensor/$deviceId/$objectId/config', jsonEncode(config), retain: true);
    }

    sensor('cpu_temperature', name: 'CPU Temperature', deviceClass: 'temperature', unit: '°C', stateClass: 'measurement');
    sensor('cpu_load', name: 'CPU Load', unit: '%', icon: 'mdi:chip', stateClass: 'measurement');
    sensor('memory_usage', name: 'Memory Usage', unit: '%', icon: 'mdi:memory', stateClass: 'measurement');
    sensor('disk_usage', name: 'Disk Usage', unit: '%', icon: 'mdi:harddisk', stateClass: 'measurement');
    sensor('ip_address', name: 'IP Address', icon: 'mdi:ip-network-outline');
    binarySensor('thermal_throttled', name: 'Thermal Throttled', deviceClass: 'problem');
    sensor('thermal_throttle_flags', name: 'Thermal Throttle Flags', icon: 'mdi:thermometer-alert');

    // Retired sensors — an empty retained payload clears Home Assistant's
    // existing discovery entry (and the state topic's own retained value),
    // removing an already-discovered entity now that this app no longer
    // publishes it. Safe to send every connect: clearing an already-cleared
    // retained topic is a no-op.
    for (final objectId in ['disk_usage', 'last_active', 'uptime']) {
      _publish('$_discoveryPrefix/sensor/$deviceId/$objectId/config', '', retain: true);
      _publish('$_baseTopic/sensor/$objectId/state', '', retain: true);
    }

    _publish(
      '$_discoveryPrefix/light/$deviceId/screen/config',
      jsonEncode({
        'name': 'Screen',
        'unique_id': '${deviceId}_screen',
        // "basic" is the only valid value for this (non-JSON, non-template)
        // schema — HA's config validation silently drops the whole payload
        // on anything else, including the seemingly-reasonable "default".
        'schema': 'basic',
        'state_topic': '$_baseTopic/light/screen/state',
        'command_topic': '$_baseTopic/light/screen/set',
        'brightness_state_topic': '$_baseTopic/light/screen/brightness_state',
        'brightness_command_topic': '$_baseTopic/light/screen/brightness_set',
        'brightness_scale': 100,
        'availability_topic': _availabilityTopic,
        'device': device,
        'icon': 'mdi:monitor',
      }),
      retain: true,
    );

    _publish(
      '$_discoveryPrefix/select/$deviceId/theme/config',
      jsonEncode({
        'name': 'Theme',
        'unique_id': '${deviceId}_theme',
        'options': [_themeOptionDark, _themeOptionLight],
        'state_topic': '$_baseTopic/select/theme/state',
        'command_topic': '$_baseTopic/select/theme/set',
        'availability_topic': _availabilityTopic,
        'device': device,
        'icon': 'mdi:theme-light-dark',
      }),
      retain: true,
    );

    void button(String objectId, {required String name, required String icon, String? deviceClass}) {
      final config = {
        'name': name,
        'unique_id': '${deviceId}_$objectId',
        'command_topic': '$_baseTopic/button/$objectId/set',
        'payload_press': 'PRESS',
        'availability_topic': _availabilityTopic,
        'device': device,
        'icon': icon,
        if (deviceClass != null) 'device_class': deviceClass,
      };
      _publish('$_discoveryPrefix/button/$deviceId/$objectId/config', jsonEncode(config), retain: true);
    }

    // No HA button device_class fits "shutdown" (valid values are just
    // identify/restart/update) — left icon-only. Reboot legitimately is
    // "restart".
    button('shutdown', name: 'Shutdown', icon: 'mdi:power');
    button('reboot', name: 'Reboot', icon: 'mdi:restart', deviceClass: 'restart');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final message = event.payload;
      if (message is! MqttPublishMessage) continue;
      final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message).trim();
      _handleCommand(event.topic, payload);
    }
  }

  void _handleCommand(String topic, String payload) {
    if (topic == '$_baseTopic/light/screen/set') {
      ScreenPowerController.instance.setPowered(payload.toUpperCase() == 'ON');
    } else if (topic == '$_baseTopic/light/screen/brightness_set') {
      final percent = int.tryParse(payload);
      if (percent == null) return;
      // A brightness of 0 is how most HA light integrations represent
      // "off" (dragging a brightness slider to its minimum sends this, not
      // a literal turn_on(brightness=0)) — treat it the same way here
      // rather than writing a literal zero brightness while the screen
      // stays nominally "on". Skipping that matters beyond just matching
      // HA's own convention: `ScreenPowerService` caches whatever brightness
      // is current when the screen next goes to sleep, to restore on wake —
      // a literal 0 sleeping into that cache means every future wake
      // restores to an invisible 0 too, so the screen looks stuck off with
      // no touch bringing it back.
      if (percent <= 0) {
        ScreenPowerController.instance.setPowered(false);
      } else {
        _brightness.setPercent(percent).then((_) => _publishBrightnessState());
      }
    } else if (topic == '$_baseTopic/button/shutdown/set') {
      debugPrint('[mqtt] shutdown requested via Home Assistant');
      _systemControl.shutdown();
    } else if (topic == '$_baseTopic/button/reboot/set') {
      debugPrint('[mqtt] reboot requested via Home Assistant');
      _systemControl.reboot();
    } else if (topic == '$_baseTopic/sheet/open') {
      SheetRegistry.instance.open(payload);
    } else if (topic == '$_baseTopic/sheet/close') {
      SheetRegistry.instance.closeTop();
    } else if (topic == '$_baseTopic/select/theme/set') {
      if (payload == _themeOptionLight) {
        ThemeModeController.instance.setMode(Brightness.light);
      } else if (payload == _themeOptionDark) {
        ThemeModeController.instance.setMode(Brightness.dark);
      }
      // The theme select's own listener (see `start`) re-publishes state
      // off the resulting `mode` change — no need to do it here too.
    }
  }

  Future<void> _publishBrightnessState() async {
    final percent = await _brightness.readPercent();
    if (percent != null) {
      _publish('$_baseTopic/light/screen/brightness_state', '$percent', retain: true);
    }
  }

  Future<void> _publishStats() async {
    final stats = await _stats.read();
    if (stats.cpuTemperatureC != null) {
      _publish('$_baseTopic/sensor/cpu_temperature/state', stats.cpuTemperatureC!.toStringAsFixed(1), retain: true);
    }
    if (stats.cpuLoadPercent != null) {
      _publish('$_baseTopic/sensor/cpu_load/state', stats.cpuLoadPercent!.toStringAsFixed(1), retain: true);
    }
    if (stats.memoryUsedPercent != null) {
      _publish('$_baseTopic/sensor/memory_usage/state', stats.memoryUsedPercent!.toStringAsFixed(1), retain: true);
    }
    if (stats.ipAddress != null) {
      _publish('$_baseTopic/sensor/ip_address/state', stats.ipAddress!, retain: true);
    }
    if (stats.thermalThrottledNow != null) {
      _publish('$_baseTopic/binary_sensor/thermal_throttled/state', stats.thermalThrottledNow! ? 'ON' : 'OFF', retain: true);
    }
    if (stats.thermalThrottleFlags != null) {
      _publish('$_baseTopic/sensor/thermal_throttle_flags/state', stats.thermalThrottleFlags!, retain: true);
    }
  }
}
