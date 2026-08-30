// Reads HA/MQTT/demo launch configuration from the process environment.
// Not argv: flutter-pi (the embedder this app actually ships on) hardcodes
// its Dart entrypoint's argument list to empty — see main.dart for the full
// story — so environment variables are the only launch-time channel that
// actually reaches the app on that embedder. A no-op stub swaps in on web,
// where `dart:io`'s `Platform.environment` doesn't exist.
export 'launch_config_stub.dart' if (dart.library.io) 'launch_config_io.dart';
