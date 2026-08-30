// Reads the Pi's own vitals (CPU temperature/load, memory, IP address) via
// Linux's `/proc` and `/sys` interfaces. A no-op stub swaps in on web, where
// `dart:io` doesn't exist.
export 'device_stats_service_stub.dart' if (dart.library.io) 'device_stats_service_io.dart';
