import 'package:flutter/foundation.dart';

import 'doorbell_history.dart';

/// Web: no disk, so the history only lasts the session.
DoorbellHistoryStore makeDoorbellHistoryStore() => _MemoryStore();

class _MemoryStore implements DoorbellHistoryStore {
  String? _json;
  final _pictures = <String, Uint8List>{};

  @override
  Future<String?> load() async => _json;

  @override
  Future<void> save(String json) async => _json = json;

  @override
  Future<void> savePicture(String id, Uint8List jpeg) async => _pictures[id] = jpeg;

  @override
  Future<Uint8List?> loadPicture(String id) async => _pictures[id];

  @override
  Future<void> deletePicture(String id) async => _pictures.remove(id);
}
