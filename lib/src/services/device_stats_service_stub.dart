import 'device_stats.dart';

/// Web build of [DeviceStatsService] — nothing to read, so every field
/// comes back null.
class DeviceStatsService {
  DeviceStatsService();

  bool get isSupported => false;

  Future<DeviceStats> read() async => const DeviceStats(
    cpuTemperatureC: null,
    cpuLoadPercent: null,
    memoryUsedPercent: null,
    ipAddress: null,
    thermalThrottledNow: null,
    thermalThrottleFlags: null,
  );
}
