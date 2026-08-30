// Turns the physical display on/off — not just its backlight brightness —
// via whatever non-DRM sysfs knobs the kernel exposes for it (see the io
// implementation for why `vcgencmd display_power` isn't the answer on a
// Pi 5). A no-op stub swaps in on web, where `dart:io` doesn't exist.
export 'screen_power_service_stub.dart' if (dart.library.io) 'screen_power_service_io.dart';
