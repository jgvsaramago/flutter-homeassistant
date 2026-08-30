import 'dart:io';

/// Shuts down / reboots the Pi via `sudo shutdown`/`sudo reboot`, triggered
/// remotely from Home Assistant (see the MQTT publisher's button entities).
///
/// This needs the app's own user to have **passwordless sudo for exactly
/// these two commands** — e.g. a sudoers.d entry like:
/// ```
/// pi ALL=(root) NOPASSWD: /sbin/shutdown -h now, /sbin/reboot
/// ```
/// Do not grant broader passwordless sudo just to make this work; a narrow
/// rule for these two exact invocations is what keeps "HA can reboot the
/// kiosk" from also meaning "anything that can reach HA can root the Pi."
/// Without that sudoers entry, both calls below fail (and are reported as
/// such) rather than silently doing nothing.
class SystemControlService {
  SystemControlService();

  bool get isSupported => Platform.isLinux;

  Future<bool> shutdown() => _run('shutdown', ['-h', 'now']);

  Future<bool> reboot() => _run('reboot', []);

  Future<bool> _run(String command, List<String> args) async {
    if (!Platform.isLinux) return false;
    try {
      final result = await Process.run('sudo', [command, ...args]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
