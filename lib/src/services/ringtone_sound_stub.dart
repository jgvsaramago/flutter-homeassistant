import 'dart:typed_data';

/// One playing tone: [done] completes when it ends or is [stop]ped.
class RingtoneSound {
  RingtoneSound._();

  Future<void> get done => Future.value();

  void stop() {}
}

/// No speakers to play on: nothing happens.
Future<RingtoneSound?> playRingtone(String id, Future<ByteData> Function() load, double volume) async => null;
