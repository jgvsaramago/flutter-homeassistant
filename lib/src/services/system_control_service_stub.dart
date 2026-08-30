/// Web build — nothing to shut down or reboot.
class SystemControlService {
  SystemControlService();

  bool get isSupported => false;

  Future<bool> shutdown() async => false;

  Future<bool> reboot() async => false;
}
