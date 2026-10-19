// Reads/writes the screen's brightness — over DDC/CI on an external HDMI
// monitor, else via Linux's `/sys/class/backlight` interface (how the
// Raspberry Pi's DSI touchscreen exposes it). A no-op stub swaps in on web, where
// `dart:io` doesn't exist.
export 'screen_brightness_service_stub.dart' if (dart.library.io) 'screen_brightness_service_io.dart';
