import 'mqtt_config.dart';

/// Web build — nothing to connect to.
class PiTelemetryPublisher {
  PiTelemetryPublisher();

  Future<void> start(MqttConfig config) async {}

  Future<void> stop() async {}
}
