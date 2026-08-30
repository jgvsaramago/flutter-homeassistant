// Shuts down / reboots the Pi via `sudo shutdown`/`sudo reboot`. A no-op
// stub swaps in on web, where `dart:io` doesn't exist.
export 'system_control_service_stub.dart' if (dart.library.io) 'system_control_service_io.dart';
