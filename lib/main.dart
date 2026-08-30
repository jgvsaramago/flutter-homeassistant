import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/dev/placeholder_entities.dart';
import 'src/ha_client/ha_connection_config.dart';
import 'src/ha_client/ha_credentials_store.dart';
import 'src/mass_client/mass_connection_config.dart';
import 'src/mass_client/mass_credentials_store.dart';
import 'src/mqtt/mqtt_config.dart';
import 'src/mqtt/mqtt_credentials_store.dart';
import 'src/mqtt/pi_telemetry_publisher.dart';
import 'src/services/launch_config.dart';

// Bump on every edit and check this against the console output on the Pi to
// confirm a rebuild actually got redeployed, rather than the old bundle
// still running.
const _buildRevision = 6;

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
  debugPrint('flutter-homeassistant build revision: $_buildRevision');

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

  final demoMode = argsAndQuery.containsKey('demo') || env['DEMO'] == 'true' || env['DEMO'] == '1';

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

    // MASS_URL/MASS_TOKEN follow the exact same launch-config convention as
    // HA_URL/HA_TOKEN above — Music Assistant is a separate service (even
    // when it runs as a HA add-on) with its own long-lived token, minted
    // from its own web UI rather than HA's.
    final massUrl = config('MASS_URL', 'mass-url');
    final massToken = config('MASS_TOKEN', 'mass-token');
    if (massUrl != null && massToken != null) {
      await MassCredentialsStore().save(MassConnectionConfig(baseUrl: massUrl, accessToken: massToken));
    }
    if (await MassCredentialsStore().read() == null) {
      debugPrint('[mass websocket] no MASS_URL/MASS_TOKEN given or previously saved — Music sheet will show no data');
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
  // The Pi touch panel's sample rate isn't a clean multiple of the display's
  // refresh rate, which makes raw pointer-driven scrolling look stepped/janky.
  // Resampling smooths that out (at the cost of a few ms of input latency) by
  // interpolating pointer position at each frame instead of only updating on
  // a raw touch sample.
  GestureBinding.instance.resamplingEnabled = true;
  // Framework default (-38ms) assumes a ~60Hz digitizer. `evtest` on this
  // panel measured only 35-40Hz (~25-29ms between raw samples), so the
  // default margin is too tight and the resampler ends up extrapolating
  // past the last real sample more often than interpolating between two —
  // which looks worse, not better. Widen it so there's reliably a bracketing
  // sample on both sides.
  GestureBinding.instance.samplingOffset = const Duration(milliseconds: -60);
  // This dashboard targets a portrait wall-mounted panel; lock rotation so
  // stray touches near the edge of the DSI screen can't flip the layout.
  // Guarded because the flutter-pi embedder doesn't implement this channel.
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  } catch (_) {}
  runApp(
    ProviderScope(
      overrides: demoMode ? placeholderOverrides : const [],
      child: const HomeAssistantApp(),
    ),
  );
}
