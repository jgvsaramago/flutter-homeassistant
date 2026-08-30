import 'package:flutter/foundation.dart';

enum MqttConnectionStatus { disabled, connecting, connected, disconnected, error }

/// App-wide MQTT publish-connection status, for Settings to display.
///
/// `PiTelemetryPublisher` is constructed directly in `main.dart`, outside
/// the Riverpod provider tree (same reasoning as `ScreenPowerController`'s
/// own doc comment) — a plain singleton is what lets Settings read its
/// status without one being threaded through as a constructor argument.
class MqttConnectionController {
  MqttConnectionController._();

  static final instance = MqttConnectionController._();

  /// Starts `disabled` — true both before `main.dart` decides whether MQTT
  /// is configured at all, and for the lifetime of a run where it isn't.
  final ValueNotifier<MqttConnectionStatus> status = ValueNotifier(MqttConnectionStatus.disabled);
}
