// Publishes the Pi's own vitals to Home Assistant over MQTT (with HA MQTT
// Discovery, so all entities show up grouped under one device automatically)
// and exposes screen power/brightness plus shutdown/reboot as controllable
// entities HA can drive back. A no-op stub swaps in on web, where the
// underlying `mqtt_client` server transport and `dart:io` don't exist.
export 'pi_telemetry_publisher_stub.dart' if (dart.library.io) 'pi_telemetry_publisher_io.dart';
