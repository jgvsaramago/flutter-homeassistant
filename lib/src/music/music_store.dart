import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/ha_providers.dart';
import 'ma_client.dart';
import 'ma_models.dart';

final maClientProvider = Provider<MaClient?>((ref) {
  final config = ref.watch(connectionConfigProvider);
  if (config == null) return null;
  final client = MaClient(ref.watch(haWebSocketClientProvider), config)..start();
  ref.onDispose(client.stop);
  return client;
});

final musicStoreProvider = ChangeNotifierProvider<MusicStore>((ref) => MusicStore(ref.watch(maClientProvider)));

/// What a queue was started from on this screen ("A TOCAR DA PLAYLIST …"),
/// which MA itself doesn't keep.
class PlayContext {
  const PlayContext(this.kind, this.title, [this.item]);

  /// Upper-case caption: `A TOCAR DA PLAYLIST`, `RÁDIO EM DIRETO`…
  final String kind;
  final String title;
  final MaItem? item;
}

/// Live Music Assistant state for the Música page: players and their
/// queues (kept current from MA's events), which speaker this screen plays
/// to, and every command the page sends.
class MusicStore extends ChangeNotifier {
  MusicStore(this.client) {
    final c = client;
    if (c == null) return;
    c.state.addListener(_onState);
    _events = c.events.listen(_onEvent);
    _onState();
    SharedPreferences.getInstance().then((p) {
      _targetId ??= p.getString(_targetKey);
      notifyListeners();
    }).ignore();
  }

  final MaClient? client;
  StreamSubscription<MaEvent>? _events;
  static const _targetKey = 'music_target_player';

  final Map<String, MaPlayer> players = {};
  final Map<String, MaQueue> queues = {};
  final Map<String, PlayContext> contexts = {};
  final List<String> recentSearches = [];
  String? _targetId;
  bool loaded = false;

  MaConnectionState get connection => client?.state.value ?? MaConnectionState.unavailable;
  bool get connected => connection == MaConnectionState.connected;

  @override
  void dispose() {
    client?.state.removeListener(_onState);
    _events?.cancel();
    super.dispose();
  }

  void _onState() {
    if (connected) {
      unawaited(_load());
    } else {
      notifyListeners();
    }
  }

  Future<void> _load() async {
    final c = client!;
    try {
      final ps = await c.call('players/all');
      final qs = await c.call('player_queues/all');
      players
        ..clear()
        ..addEntries([for (final p in (ps as List)) ?MaPlayer.tryParse(p)].map((p) => MapEntry(p.id, p)));
      queues
        ..clear()
        ..addEntries([for (final q in (qs as List)) ?MaQueue.tryParse(q)].map((q) => MapEntry(q.id, q)));
      loaded = true;
      _pickTarget();
      notifyListeners();
    } catch (e) {
      debugPrint('[music] load failed: $e');
    }
  }

  void _onEvent(MaEvent e) {
    switch (e.event) {
      case 'player_added' || 'player_updated':
        final p = MaPlayer.tryParse(e.data);
        if (p != null) {
          players[p.id] = p;
        } else if (e.objectId != null) {
          players.remove(e.objectId);
        }
      case 'player_removed':
        players.remove(e.objectId);
      case 'queue_added' || 'queue_updated':
        final q = MaQueue.tryParse(e.data);
        if (q != null) queues[q.id] = q;
      case 'queue_time_updated':
        final q = queues[e.objectId];
        if (q != null && e.data is num) queues[q.id] = q.withElapsed((e.data as num).toDouble());
      case 'queue_items_updated':
        queueItemsVersion++;
      case 'media_item_updated':
        favoritesVersion++;
      default:
        return;
    }
    notifyListeners();
  }

  /// Bumped when a queue's items change, so an open "Fila" reloads.
  int queueItemsVersion = 0;

  /// Bumped when a library item changes (a heart toggled elsewhere).
  int favoritesVersion = 0;

  // ---------------------------------------------------------------- players

  List<MaPlayer> get speakers => players.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void _pickTarget() {
    if (_targetId != null && players[_targetId!]?.available == true) return;
    final playing = queues.values.where((q) => q.playing && players.containsKey(q.id)).firstOrNull;
    final pick = playing?.id ?? speakers.where((p) => p.available).map((p) => p.id).firstOrNull;
    if (pick != null) _targetId = pick;
  }

  MaPlayer? get target => _targetId == null ? null : players[_targetId!];

  Future<void> setTarget(String id) async {
    _targetId = id;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(_targetKey, id);
  }

  /// The target and whoever is grouped with it.
  List<MaPlayer> get active {
    final t = target;
    if (t == null) return const [];
    return [t, for (final id in t.groupMembers) if (id != t.id) ?players[id]];
  }

  String get targetLabel {
    final on = active;
    if (on.isEmpty) return 'Sem colunas';
    if (on.length <= 2) return on.map((p) => p.name).join(' + ');
    return '${on.first.name} + ${on.length - 1} colunas';
  }

  MaQueue? get queue {
    final t = target;
    if (t == null) return null;
    return queues[t.queueId] ?? queues[t.id];
  }

  PlayContext? get context => queue == null ? null : contexts[queue!.id];

  /// Sessions playing on speakers outside this screen's group.
  List<({MaPlayer player, MaQueue queue})> get others {
    final mine = active.map((p) => p.id).toSet();
    return [
      for (final p in speakers)
        if (!mine.contains(p.id) && p.syncedTo == null && queues[p.queueId]?.playing == true) (player: p, queue: queues[p.queueId]!),
    ];
  }

  // --------------------------------------------------------------- playback

  Future<dynamic> _cmd(String command, Map<String, dynamic> args) {
    final c = client;
    if (c == null) return Future.error(StateError('Music Assistant indisponível'));
    return c.call(command, args);
  }

  String? get _queueId => queue?.id ?? target?.id;

  Future<void> play(dynamic media, {PlayContext? context, String? startItem, bool shuffle = false, bool radio = false, String option = 'replace'}) async {
    final q = _queueId;
    if (q == null) throw StateError('Escolha uma coluna');
    if (context != null && option == 'replace') contexts[q] = context;
    await _cmd('player_queues/play_media', {
      'queue_id': q,
      'media': media,
      'option': option,
      'start_item': ?startItem,
      if (shuffle) 'shuffle': true,
      if (radio) 'radio_mode': true,
    });
    if (shuffle && queue?.shuffle != true) await _cmd('player_queues/shuffle', {'queue_id': q, 'shuffle_enabled': true});
  }

  Future<void> playPause() => _cmd('player_queues/play_pause', {'queue_id': _queueId});
  Future<void> next() => _cmd('player_queues/next', {'queue_id': _queueId});
  Future<void> previous() => _cmd('player_queues/previous', {'queue_id': _queueId});
  Future<void> seek(int seconds) => _cmd('player_queues/seek', {'queue_id': _queueId, 'position': seconds});
  Future<void> setShuffle(bool on) => _cmd('player_queues/shuffle', {'queue_id': _queueId, 'shuffle_enabled': on});

  Future<void> cycleRepeat() {
    final next = switch (queue?.repeat) {
      'off' => 'all',
      'all' => 'one',
      _ => 'off',
    };
    return _cmd('player_queues/repeat', {'queue_id': _queueId, 'repeat_mode': next});
  }

  Future<List<MaQueueItem>> upcoming({int limit = 30}) async {
    final q = queue;
    if (q == null) return const [];
    final r = await _cmd('player_queues/items', {'queue_id': q.id, 'limit': limit, 'offset': (q.currentIndex ?? -1) + 1});
    return [for (final x in (r as List? ?? const [])) ?MaQueueItem.tryParse(x)];
  }

  Future<void> playQueueItem(String queueItemId) => _cmd('player_queues/play_index', {'queue_id': _queueId, 'index': queueItemId});
  Future<void> removeQueueItem(String queueItemId) => _cmd('player_queues/delete_item', {'queue_id': _queueId, 'item_id_or_index': queueItemId});

  /// Drops what's coming up, keeping the current track playing.
  Future<void> clearUpcoming() async {
    for (final item in await upcoming(limit: 500)) {
      await removeQueueItem(item.queueItemId);
    }
  }

  // ---------------------------------------------------------------- volume

  Future<void> setVolume(String playerId, int v) async {
    final p = players[playerId];
    if (p != null) players[playerId] = _withVolume(p, v);
    notifyListeners();
    await _cmd('players/cmd/volume_set', {'player_id': playerId, 'volume_level': v});
  }

  Future<void> setGroupVolume(int v) async {
    final on = active;
    if (on.isEmpty) return;
    if (on.length == 1) return setVolume(on.first.id, v);
    final avg = groupVolume;
    for (final p in on) {
      players[p.id] = _withVolume(p, ((p.volume ?? 0) + v - avg).clamp(0, 100));
    }
    notifyListeners();
    await _cmd('players/cmd/group_volume', {'player_id': on.first.id, 'volume_level': v});
  }

  int get groupVolume {
    final on = active.where((p) => p.volume != null).toList();
    if (on.isEmpty) return 0;
    return (on.fold<int>(0, (a, p) => a + p.volume!) / on.length).round();
  }

  MaPlayer _withVolume(MaPlayer p, int v) => MaPlayer(
    id: p.id,
    name: p.name,
    available: p.available,
    volume: v,
    groupMembers: p.groupMembers,
    canGroupWith: p.canGroupWith,
    model: p.model,
    manufacturer: p.manufacturer,
    provider: p.provider,
    activeSource: p.activeSource,
    syncedTo: p.syncedTo,
    activeGroup: p.activeGroup,
  );

  // ---------------------------------------------------------------- groups

  bool canJoin(MaPlayer p) {
    final t = target;
    if (t == null || !p.available) return false;
    return t.canGroupWith.contains(p.id) || t.canGroupWith.contains(p.provider);
  }

  /// Adds [id] to this screen's group, or takes it out. Taking out the
  /// group's leader hands the music to the next speaker in the group.
  Future<void> toggleSpeaker(String id) async {
    final t = target;
    final p = players[id];
    if (p == null || !p.available) return;
    if (t == null) return setTarget(id);
    final on = active.map((x) => x.id).toList();
    if (id == t.id) {
      final rest = on.where((x) => x != t.id).toList();
      if (rest.isEmpty) return; // one speaker always stays
      await _cmd('players/cmd/set_members', {'target_player': t.id, 'player_ids_to_remove': rest});
      final q = queue;
      if (q != null && q.current != null) {
        await _cmd('player_queues/transfer', {'source_queue_id': q.id, 'target_queue_id': rest.first, 'auto_play': q.playing});
      }
      await setTarget(rest.first);
      if (rest.length > 1) await _cmd('players/cmd/set_members', {'target_player': rest.first, 'player_ids_to_add': rest.sublist(1)});
      return;
    }
    if (on.contains(id)) {
      await _cmd('players/cmd/set_members', {'target_player': t.id, 'player_ids_to_remove': [id]});
    } else {
      if (!canJoin(p)) throw StateError('${p.name} não pode tocar em grupo com ${t.name}');
      await _cmd('players/cmd/set_members', {'target_player': t.id, 'player_ids_to_add': [id]});
    }
  }

  /// Makes exactly [ids] the group (when they can play together).
  Future<void> setGroup(List<String> ids) async {
    final t = target;
    if (t == null || ids.isEmpty) return;
    final want = ids.where((id) => id == t.id || (players[id] != null && canJoin(players[id]!))).toSet();
    final on = active.map((p) => p.id).toSet();
    final add = want.difference(on).where((id) => id != t.id).toList();
    final remove = on.difference(want).where((id) => id != t.id).toList();
    if (add.isEmpty && remove.isEmpty) return;
    await _cmd('players/cmd/set_members', {
      'target_player': t.id,
      if (add.isNotEmpty) 'player_ids_to_add': add,
      if (remove.isNotEmpty) 'player_ids_to_remove': remove,
    });
  }

  // ---------------------------------------------------------------- library

  Future<List<MaItem>> library(String kind, {String orderBy = 'last_played_desc', bool favorite = false, int limit = 100}) async {
    final r = await _cmd('music/$kind/library_items', {'limit': limit, 'order_by': orderBy, if (favorite) 'favorite': true});
    return MaItem.list(r);
  }

  Future<List<MaItem>> recentlyPlayed({int limit = 12}) async {
    final r = await _cmd('music/recently_played_items', {
      'limit': limit,
      'media_types': ['playlist', 'album', 'artist', 'radio', 'podcast'],
    });
    return MaItem.list(r);
  }

  Future<MaSearchResults> search(String query) async {
    final r = await _cmd('music/search', {'search_query': query, 'limit': 12});
    final q = query.trim();
    if (q.isNotEmpty) {
      recentSearches
        ..removeWhere((s) => s.toLowerCase() == q.toLowerCase())
        ..insert(0, q);
      if (recentSearches.length > 8) recentSearches.removeLast();
    }
    return MaSearchResults.fromJson(r);
  }

  Future<List<MaItem>> tracksOf(MaItem item) async {
    final args = {'item_id': item.itemId, 'provider_instance_id_or_domain': item.provider};
    final r = switch (item.mediaType) {
      'playlist' => await _cmd('music/playlists/playlist_tracks', args),
      'album' => await _cmd('music/albums/album_tracks', args),
      'podcast' => await _cmd('music/podcasts/podcast_episodes', args),
      'artist' => await _cmd('music/artists/artist_tracks', args),
      _ => const [],
    };
    return MaItem.list(r);
  }

  Future<List<MaItem>> albumsOf(MaItem artist) async {
    final r = await _cmd('music/artists/artist_albums', {'item_id': artist.itemId, 'provider_instance_id_or_domain': artist.provider});
    return MaItem.list(r);
  }

  /// Hearts [item] (adds it to the library's favourites) or un-hearts it.
  Future<void> setFavorite(MaItem item, bool on) async {
    if (on) {
      await _cmd('music/favorites/add_item', {'item': item.uri});
      return;
    }
    var libraryId = item.isLibrary ? item.itemId : null;
    if (libraryId == null) {
      final lib = MaItem.tryParse(await _cmd('music/item_by_uri', {'uri': item.uri}));
      if (lib != null && lib.isLibrary) libraryId = lib.itemId;
    }
    if (libraryId == null) return;
    await _cmd('music/favorites/remove_item', {'media_type': item.mediaType, 'library_item_id': libraryId});
  }

  /// MA's library version of [item], to read its current favourite flag.
  Future<MaItem?> refresh(MaItem item) async => MaItem.tryParse(await _cmd('music/item_by_uri', {'uri': item.uri}));
}
