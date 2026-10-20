import 'dart:typed_data';

import 'door_station.dart';

/// Web/non-dart:io fallback: no door station reachable, so every call is a
/// no-op. Keeps the app compiling for browser preview, where there's no
/// intercom VLAN and `dart:io`'s HTTP stack isn't available anyway.
DoorStation makeDoorStation(DoorStationConfig config) => _NoDoorStation();

class _NoDoorStation implements DoorStation {
  @override
  Future<Uint8List?> snapshot({int? channel}) async => null;

  @override
  Future<void> unlock() async {}

  @override
  String get rtspUrl => '';

  @override
  String get rtspUrlMain => '';

  @override
  void dispose() {}
}
