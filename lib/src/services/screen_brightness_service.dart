// Reads/writes the device's screen backlight brightness via Linux's
// `/sys/class/backlight` interface (how the Raspberry Pi's DSI touchscreen
// exposes brightness control). A no-op stub swaps in on web, where
// `dart:io` doesn't exist.
export 'screen_brightness_service_stub.dart' if (dart.library.io) 'screen_brightness_service_io.dart';
