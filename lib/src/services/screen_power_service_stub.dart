/// Web build of [ScreenPowerService] — nothing to power off, so every call
/// reports "unsupported" rather than doing anything.
class ScreenPowerService {
  ScreenPowerService();

  bool get isSupported => false;

  Future<bool> setPowered(bool on, {void Function()? onMidTransition}) async => false;
}
