import 'dart:async';

import 'package:flutter/foundation.dart';

import 'doorbell_watcher.dart';
import 'sip_extension.dart';

/// Web/no-io stand-in: never registers, never rings, and says so — same shape
/// as [MissingDoorbellWatcher] so the shell can warn.
SipExtension startSipExtension(SipExtensionConfig config) => _StubSipExtension();

class _StubSipExtension implements SipExtension {
  final _problem = ValueNotifier<String?>(
    'A extensão SIP só funciona no dispositivo (Pi), não na pré-visualização web.',
  );

  @override
  Stream<IndoorCallStatus> get calls => const Stream.empty();

  @override
  ValueListenable<String?> get problem => _problem;

  @override
  SipCallMedia? get activeMedia => null;

  @override
  void answer() {}

  @override
  void hangup() {}

  @override
  bool unlockViaInfo() => false;

  @override
  void dispose() => _problem.dispose();
}
