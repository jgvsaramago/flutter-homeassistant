import 'dart:io';

import 'device_stats.dart';

/// Reads the Pi's own vitals straight out of `/proc` and `/sys` — no extra
/// packages, since these are plain text files the kernel already exposes.
/// Every read is independently best-effort: a field that fails to parse
/// (a differently-laid-out `/proc/meminfo`, no thermal zone on this board,
/// ...) comes back null rather than taking the others down with it.
class DeviceStatsService {
  DeviceStatsService();

  bool get isSupported => Platform.isLinux;

  Future<DeviceStats> read() async {
    if (!Platform.isLinux) {
      return const DeviceStats(
        cpuTemperatureC: null,
        cpuLoadPercent: null,
        memoryUsedPercent: null,
        ipAddress: null,
        thermalThrottledNow: null,
        thermalThrottleFlags: null,
      );
    }

    final throttled = await _throttledRaw();
    return DeviceStats(
      cpuTemperatureC: await _cpuTemperatureC(),
      cpuLoadPercent: await _cpuLoadPercent(),
      memoryUsedPercent: await _memoryUsedPercent(),
      ipAddress: await _ipAddress(),
      thermalThrottledNow: throttled == null ? null : (throttled & 0xF) != 0,
      thermalThrottleFlags: throttled == null ? null : _describeThrottled(throttled),
    );
  }

  /// Raw bitmask from `vcgencmd get_throttled` — only present on Raspberry
  /// Pi OS (backed by the VideoCore firmware, unrelated to the DRM/KMS
  /// display stack, so this works regardless of the display situation).
  /// Bits 0-3 (the only ones this reads) are the live state; the firmware
  /// also sets bits 16-19 as a "has this ever happened since boot" latch
  /// that only clears on reboot — deliberately not read here, since HA's
  /// own history on the resulting entities already answers "did this ever
  /// happen" without a bit that can never turn back off on its own. See
  /// https://www.raspberrypi.com/documentation/computers/os.html#get_throttled.
  Future<int?> _throttledRaw() async {
    try {
      final result = await Process.run('vcgencmd', ['get_throttled']);
      if (result.exitCode != 0) return null;
      final match = RegExp(r'throttled=0x([0-9a-fA-F]+)').firstMatch(result.stdout as String);
      if (match == null) return null;
      return int.parse(match.group(1)!, radix: 16);
    } catch (_) {
      return null; // vcgencmd isn't present outside Raspberry Pi OS
    }
  }

  static const _throttledFlagLabels = {0: 'under_voltage', 1: 'freq_capped', 2: 'throttled', 3: 'soft_temp_limit'};

  String _describeThrottled(int raw) {
    final active = [for (final entry in _throttledFlagLabels.entries) if ((raw >> entry.key) & 1 == 1) entry.value];
    return active.isEmpty ? 'none' : active.join(',');
  }

  Future<double?> _cpuTemperatureC() async {
    try {
      final raw = await File('/sys/class/thermal/thermal_zone0/temp').readAsString();
      return int.parse(raw.trim()) / 1000.0;
    } catch (_) {
      return null;
    }
  }

  /// Matches Touchkio's own `getProcessorUsage()` (`os.loadavg()[1] /
  /// os.cpus().length * 100`) exactly, column-for-column, so this app's
  /// reported CPU load is directly comparable to Touchkio's — both are the
  /// 5-minute load average as a percentage of total core count. Chosen
  /// deliberately over a true instantaneous reading (which this app used
  /// briefly) specifically so the two numbers mean the same thing side by
  /// side; it inherits load average's usual caveats (minutes-long lag,
  /// counts I/O-wait too) same as Touchkio's number does.
  Future<double?> _cpuLoadPercent() async {
    try {
      final raw = await File('/proc/loadavg').readAsString();
      final fiveMinuteAvg = double.parse(raw.trim().split(' ')[1]);
      final cores = Platform.numberOfProcessors;
      if (cores <= 0) return null;
      return (fiveMinuteAvg / cores) * 100;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _memoryUsedPercent() async {
    try {
      final lines = await File('/proc/meminfo').readAsLines();
      int? totalKb;
      int? availableKb;
      for (final line in lines) {
        if (line.startsWith('MemTotal:')) {
          totalKb = int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!);
        } else if (line.startsWith('MemAvailable:')) {
          availableKb = int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!);
        }
      }
      if (totalKb == null || availableKb == null || totalKb == 0) return null;
      return (totalKb - availableKb) / totalKb * 100;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _ipAddress() async {
    try {
      final interfaces = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
