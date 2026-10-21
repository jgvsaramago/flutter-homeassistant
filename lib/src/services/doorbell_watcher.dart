import 'dart:async';

import 'package:flutter/foundation.dart';

import 'doorbell_watcher_stub.dart' if (dart.library.io) 'doorbell_watcher_io.dart' as impl;

/// The call state of the user's own indoor station (the Hikvision KH8350).
///
/// The building's door station is shared, and its own call state is global —
/// "ringing" for *any* apartment. The indoor station only rings for this
/// apartment, so its state is the apartment-specific doorbell signal.
enum IndoorCallStatus { idle, ringing, onCall }

/// How to reach the indoor station. It has no HTTP API (ports 80/443 are
/// closed); it's read through Hikvision's HCNetSDK on port 8000, from the
/// SDK's native library installed on the Pi at [sdkDir] (proprietary, so it
/// isn't part of this repo — see pi/hcnetsdk/README.md).
class IndoorStationConfig {
  const IndoorStationConfig({
    required this.host,
    required this.username,
    required this.password,
    this.port = 8000,
    this.sdkDir = '/opt/hcnetsdk',
  });

  final String host;
  final String username;
  final String password;
  final int port;
  final String sdkDir;
}

/// Watches the indoor station for this apartment's doorbell.
abstract class DoorbellWatcher {
  /// The indoor station's call state, emitted when it changes.
  Stream<IndoorCallStatus> get calls;

  /// Why a ring would currently NOT reach this screen, or null while the
  /// link is healthy. Meant to be shown loudly: a silently broken doorbell
  /// is the one failure the intercom must never have.
  ValueListenable<String?> get problem;

  void dispose();
}

/// Starts watching on a background isolate (on the Pi; a no-op off it).
DoorbellWatcher startDoorbellWatcher(IndoorStationConfig config) => impl.startDoorbellWatcher(config);

/// Stands in when no indoor station is configured: the door camera works,
/// but rings can't reach the screen — and it says so.
class MissingDoorbellWatcher implements DoorbellWatcher {
  MissingDoorbellWatcher();

  final _problem = ValueNotifier<String?>(
    'O intercomunicador de casa não está configurado neste ecrã (INDOOR_HOST).',
  );

  @override
  Stream<IndoorCallStatus> get calls => const Stream.empty();

  @override
  ValueListenable<String?> get problem => _problem;

  @override
  void dispose() {}
}
