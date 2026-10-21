import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/build_info.dart';
import 'src/dev/placeholder_entities.dart';
import 'src/ha_client/ha_connection_config.dart';
import 'src/ha_client/ha_credentials_store.dart';
import 'src/kiosk/modals/intercom_modal.dart';
import 'src/mqtt/mqtt_config.dart';
import 'src/mqtt/mqtt_credentials_store.dart';
import 'src/mqtt/pi_telemetry_publisher.dart';
import 'src/services/door_station.dart';
import 'src/services/door_video.dart';
import 'src/services/doorbell_watcher.dart';
import 'src/services/frame_stats_logger.dart';
import 'src/services/launch_config.dart';
import 'src/theme/theme_mode_controller.dart';

// Bump on every edit and check this against the console output on the Pi to
// confirm a rebuild actually got redeployed, rather than the old bundle
// still running.
// See build_info.dart.

/// Parses `--key=value` (and bare `--flag`) launch arguments. Kept as a
/// secondary source alongside environment variables (see below for why
/// env vars are the primary one) — harmless, and it's what actually works
/// on platforms other than flutter-pi (desktop, web via ?query=params).
Map<String, String> _parseArgs(List<String> args) {
  final parsed = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) continue;
    final eq = arg.indexOf('=');
    if (eq == -1) {
      parsed[arg.substring(2)] = 'true';
    } else {
      parsed[arg.substring(2, eq)] = arg.substring(eq + 1);
    }
  }
  return parsed;
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('flutter-homeassistant build revision: $kBuildRevision');

  // Restored before the first frame so the app paints in the right theme
  // immediately, rather than flashing dark then swapping once this
  // resolves.
  await ThemeModeController.instance.restore();

  // Environment variables are the primary launch-config channel, not argv:
  // flutter-pi (the embedder this app ships on) hardcodes its Dart
  // entrypoint's argument list to empty — dart_entrypoint_argc/argv are
  // always 0/NULL in its source — regardless of where flags are placed on
  // the command line. Env vars are inherited through the OS process model
  // instead, so they reach the app even though argv never does there.
  final env = readLaunchEnvironment();
  // Argv (native, non-flutter-pi platforms) and the URL's query string
  // (web) as secondary sources — e.g. ?demo=true still works for previewing
  // the UI in a browser with no HA/MQTT setup at all.
  final argsAndQuery = {..._parseArgs(args), ...Uri.base.queryParameters};
  String? config(String envKey, String argKey) => env[envKey] ?? argsAndQuery[argKey];

  // A one-off preview override (?theme=light/dark, --theme=light/dark) —
  // same idea as ?demo=true, doesn't touch the persisted preference, so
  // reloading without it falls back to whatever was actually saved/set via
  // MQTT.
  final themeOverride = config('THEME', 'theme');
  if (themeOverride == 'light') {
    ThemeModeController.instance.mode.value = Brightness.light;
  } else if (themeOverride == 'dark') {
    ThemeModeController.instance.mode.value = Brightness.dark;
  }

  final demoMode = argsAndQuery.containsKey('demo') || env['DEMO'] == 'true' || env['DEMO'] == '1';

  // The door station (Hikvision villa intercom) the kiosk shows and unlocks.
  // Configured like HA/MQTT: baked into the launch environment on the Pi
  // (DOOR_HOST on the intercom VLAN, DOOR_USER/DOOR_PASSWORD). When it isn't
  // set — or on web — the intercom screen keeps its NotConnected stub.
  IntercomController? doorIntercom;

  if (!demoMode) {
    // HA_URL/HA_TOKEN let a kiosk boot straight past onboarding with
    // credentials baked into the launch environment (a systemd unit's
    // Environment=/EnvironmentFile=) instead of someone manually typing
    // them into the touch screen. Once seen, they're persisted, so later
    // boots work even if something launches the process without them.
    final haUrl = config('HA_URL', 'ha-url');
    final haToken = config('HA_TOKEN', 'ha-token');
    if (haUrl != null && haToken != null) {
      await HaCredentialsStore().save(HaConnectionConfig(baseUrl: haUrl, accessToken: haToken));
    }
    if (await HaCredentialsStore().read() == null) {
      debugPrint('[ha websocket] no HA_URL/HA_TOKEN given or previously saved — dashboard will show no data');
    }

    final mqttHost = config('MQTT_HOST', 'mqtt-host');
    if (mqttHost != null) {
      await MqttCredentialsStore().save(
        MqttConfig(
          host: mqttHost,
          port: int.tryParse(config('MQTT_PORT', 'mqtt-port') ?? '') ?? 1883,
          username: config('MQTT_USERNAME', 'mqtt-username'),
          password: config('MQTT_PASSWORD', 'mqtt-password'),
        ),
      );
    }

    final mqttConfig = await MqttCredentialsStore().read();
    if (mqttConfig != null) {
      // Fire-and-forget: the publisher connects and keeps itself alive via
      // its own Timer/stream subscription, same as the app doesn't block
      // startup on the HA websocket connecting either.
      unawaited(PiTelemetryPublisher().start(mqttConfig));
    } else {
      debugPrint('[mqtt] no MQTT_HOST given or previously saved — device telemetry will not be published');
    }

    final doorHost = config('DOOR_HOST', 'door-host');
    if (doorHost != null && doorHost.isNotEmpty) {
      final station = createDoorStation(
        DoorStationConfig(
          host: doorHost,
          port: int.tryParse(config('DOOR_PORT', 'door-port') ?? '') ?? 80,
          username: config('DOOR_USER', 'door-user') ?? 'admin',
          password: config('DOOR_PASSWORD', 'door-password') ?? '',
          channel: int.tryParse(config('DOOR_CHANNEL', 'door-channel') ?? '') ?? 101,
          doorNo: int.tryParse(config('DOOR_NO', 'door-no') ?? '') ?? 1,
        ),
      );
      // The doorbell comes from this apartment's own indoor station; without
      // one configured the camera still works, but the shell warns loudly
      // that rings won't reach the screen.
      final indoorHost = config('INDOOR_HOST', 'indoor-host');
      final doorbell = indoorHost == null || indoorHost.isEmpty
          ? MissingDoorbellWatcher()
          : startDoorbellWatcher(
              IndoorStationConfig(
                host: indoorHost,
                port: int.tryParse(config('INDOOR_PORT', 'indoor-port') ?? '') ?? 8000,
                username: config('INDOOR_USER', 'indoor-user') ?? 'admin',
                password: config('INDOOR_PASSWORD', 'indoor-password') ?? '',
                sdkDir: config('HIK_SDK_DIR', 'hik-sdk-dir') ?? '/opt/hcnetsdk',
              ),
            );
      doorIntercom = DoorStationIntercom(station, doorbell: doorbell);
    } else {
      debugPrint('[door] no DOOR_HOST given — intercom screen will show "not connected"');
    }
  }
  final view = ui.PlatformDispatcher.instance.implicitView;
  if (view != null) {
    // Size/Offset etc. have their toString() stripped in release builds, so
    // interpolate the fields directly rather than the Size object itself.
    final size = view.physicalSize;
    debugPrint(
      'display: physicalSize=${size.width}x${size.height} '
      'devicePixelRatio=${view.devicePixelRatio} '
      'logicalSize=${size.width / view.devicePixelRatio}x${size.height / view.devicePixelRatio}',
    );
  }
  // This dashboard targets a portrait wall-mounted panel; lock rotation so
  // stray touches near the edge of the DSI screen can't flip the layout.
  // Guarded because the flutter-pi embedder doesn't implement this channel.
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  } catch (_) {}
  final fpsLog = config('FPS_LOG', 'fps-log');
  if (fpsLog == '1' || fpsLog == 'true') startFrameStatsLogger();
  // Install the flutter-pi gstreamer backend for video_player, so the intercom
  // can show the door's live RTSP stream (no-op on web). Must be before runApp.
  registerDoorVideo();
  runApp(
    ProviderScope(
      overrides: [
        if (demoMode) ...placeholderOverrides,
        if (doorIntercom != null) intercomControllerProvider.overrideWithValue(doorIntercom),
      ],
      child: const HomeAssistantApp(),
    ),
  );
}
