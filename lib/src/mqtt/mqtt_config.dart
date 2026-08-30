/// Connection details for the MQTT broker the Pi publishes its telemetry
/// and control entities to — separate from the Home Assistant connection
/// config, since the broker isn't necessarily on the same host as HA itself
/// (its own Mosquitto add-on typically is, but a standalone broker isn't).
class MqttConfig {
  const MqttConfig({required this.host, this.port = 1883, this.username, this.password});

  final String host;
  final int port;
  final String? username;
  final String? password;
}
