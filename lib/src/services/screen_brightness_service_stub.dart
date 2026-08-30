/// Web build of [ScreenBrightnessService] — there's no backlight to
/// control, so every call reports "unsupported" rather than touching
/// anything.
class ScreenBrightnessService {
  const ScreenBrightnessService();

  bool get isSupported => false;

  Future<int?> readPercent() async => null;

  Future<bool> setPercent(int percent) async => false;
}
