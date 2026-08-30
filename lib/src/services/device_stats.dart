/// A snapshot of the Pi's own vitals, as read by `DeviceStatsService`.
class DeviceStats {
  const DeviceStats({
    required this.cpuTemperatureC,
    required this.cpuLoadPercent,
    required this.memoryUsedPercent,
    required this.ipAddress,
    required this.thermalThrottledNow,
    required this.thermalThrottleFlags,
  });

  final double? cpuTemperatureC;

  /// System-wide CPU load — see `_cpuLoadPercent` in
  /// `DeviceStatsService` for why this deliberately matches Touchkio's
  /// own formula rather than reading real-time usage.
  final double? cpuLoadPercent;

  final double? memoryUsedPercent;
  final String? ipAddress;

  /// True if the Raspberry Pi firmware reports an active problem right now
  /// (under-voltage, ARM frequency capping, active throttling, or the soft
  /// temperature limit). Deliberately ignores the firmware's separate
  /// "has this happened since boot" latch bits — those never clear without
  /// a reboot, so folding them in here would make this permanently true
  /// after any one transient blip; HA's own history on this entity is
  /// already the record of when it happened. Null if `vcgencmd` isn't
  /// available (non-Pi/non-Linux).
  final bool? thermalThrottledNow;

  /// Comma-separated diagnostic detail behind [thermalThrottledNow] — which
  /// of the four current-state flags `vcgencmd get_throttled` has set, or
  /// `"none"` if none are.
  final String? thermalThrottleFlags;
}
