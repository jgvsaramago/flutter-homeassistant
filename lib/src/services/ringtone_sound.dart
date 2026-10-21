// Plays one ringtone WAV through the monitor's speakers — flutter-pi only.
// A no-op on web.
export 'ringtone_sound_stub.dart' if (dart.library.io) 'ringtone_sound_io.dart';
