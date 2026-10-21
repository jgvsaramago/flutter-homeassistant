import 'dart:io';

import 'package:flutter/foundation.dart';

import 'doorbell_history.dart';

DoorbellHistoryStore makeDoorbellHistoryStore() => _FileStore();

/// The history lives on the Pi's own disk (the intercom works without Home
/// Assistant, so its history does too): `~/.local/share/flutter-homeassistant/doorbell/`.
class _FileStore implements DoorbellHistoryStore {
  _FileStore() : _dir = Directory('${Platform.environment['HOME'] ?? '/tmp'}/.local/share/flutter-homeassistant/doorbell');

  final Directory _dir;

  File get _list => File('${_dir.path}/history.json');
  File _picture(String id) => File('${_dir.path}/$id.jpg');

  @override
  Future<String?> load() async => await _list.exists() ? _list.readAsString() : null;

  @override
  Future<void> save(String json) async {
    await _dir.create(recursive: true);
    // Write-then-rename, so a power cut mid-write can't leave half a file.
    final tmp = File('${_list.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_list.path);
  }

  @override
  Future<void> savePicture(String id, Uint8List jpeg) async {
    await _dir.create(recursive: true);
    await _picture(id).writeAsBytes(jpeg, flush: true);
  }

  @override
  Future<Uint8List?> loadPicture(String id) async {
    final f = _picture(id);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> deletePicture(String id) async {
    final f = _picture(id);
    if (await f.exists()) await f.delete();
  }
}
