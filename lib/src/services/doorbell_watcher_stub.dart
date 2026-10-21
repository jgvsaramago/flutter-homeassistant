import 'package:flutter/foundation.dart';

import 'doorbell_watcher.dart';

/// Web/non-dart:io fallback: there's no indoor station to reach from a browser
/// preview, so nothing rings and nothing is reported as broken.
DoorbellWatcher startDoorbellWatcher(IndoorStationConfig config) => _NoDoorbellWatcher();

class _NoDoorbellWatcher implements DoorbellWatcher {
  final _problem = ValueNotifier<String?>(null);

  @override
  Stream<IndoorCallStatus> get calls => const Stream.empty();

  @override
  ValueListenable<String?> get problem => _problem;

  @override
  void dispose() {}
}
