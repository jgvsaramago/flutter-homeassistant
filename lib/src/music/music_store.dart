import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/ha_providers.dart';
import '../utils/optimistic.dart';
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
///
/// Commands show their effect at once (pause, volume, grouping…) and go
/// back if MA doesn't report it within a few seconds — see
/// [OptimisticLayer].
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

  final Map<String, MaPlayer> _players = {};
  final Map<String, MaQueue> _queues = {};

  /// As shown: MA's, with this screen's unconfirmed changes on top.
  Map<String, MaPlayer> players = const {};
  Map<String, MaQueue> queues = const {};

  static const _notConfirmed = 'O Music Assistant não confirmou a alteração';
  late final _playerLayer = OptimisticLayer<MaPlayer>(real: (id) => _players[id], onChanged: _publish, notConfirmed: _notConfirmed);
  late final _queueLayer = OptimisticLayer<MaQueue>(real: (id) => _queues[id], onChanged: _publish, notConfirmed: _notConfirmed);

  void _publish() {
    players = _playerLayer.overlay(_players);
    queues = _queueLayer.overlay(_queues);
    notifyListeners();
  }

  void _settleAndPublish() {
    _playerLayer.settle();
    _queueLayer.settle();
    _publish();
  }
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
    _playerLayer.dispose();
    _queueLayer.dispose();
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
      _players
        ..clear()
        ..addEntries([for (final p in (ps as List)) ?MaPlayer.tryParse(p)].map((p) => MapEntry(p.id, p)));
      _queues
        ..clear()
        ..addEntries([for (final q in (qs as List)) ?MaQueue.tryParse(q)].map((q) => MapEntry(q.id, q)));
      loaded = true;
      _pickTarget();
      _settleAndPublish();
    } catch (e) {
      debugPrint('[music] load failed: $e');
    }
  }

  void _onEvent(MaEvent e) {
    switch (e.event) {
      case 'player_added' || 'player_updated':
        final p = MaPlayer.tryParse(e.data);
        if (p != null) {
          _players[p.id] = p;
        } else if (e.objectId != null) {
          _players.remove(e.objectId);
        }
      case 'player_removed':
        _players.remove(e.objectId);
      case 'queue_added' || 'queue_updated':
        final q = MaQueue.tryParse(e.data);
        if (q != null) _queues[q.id] = q;
      case 'queue_time_updated':
        final q = _queues[e.objectId];
        if (q != null && e.data is num) _queues[q.id] = q.withElapsed((e.data as num).toDouble());
      case 'queue_items_updated':
        queueItemsVersion++;
      case 'media_item_updated':
        favoritesVersion++;
      default:
        return;
    }
    _settleAndPublish();
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

  /// Runs [command] on the current queue, showing [patch] until MA's
  /// queue reports [confirmed].
  Future<void> _onQueue(String command, Map<String, dynamic> args, String slot, MaQueue Function(MaQueue) patch, bool Function(MaQueue) confirmed) {
    final q = queue;
    Future<void> run() => _cmd(command, {'queue_id': _queueId, ...args});
    if (q == null) return run();
    return _queueLayer.run([OptimisticChange(q.id, slot: slot, patch: patch, confirmed: confirmed)], run);
  }

  Future<void> playPause() {
    final now = DateTime.now();
    final play = queue?.playing != true;
    final at = queue?.position(now) ?? 0;
    return _onQueue(
      'player_queues/play_pause',
      const {},
      'state',
      (q) => q.copyWith(state: play ? 'playing' : 'paused', elapsed: at, elapsedAt: now),
      (q) => q.playing == play,
    );
  }

  Future<void> next() {
    final from = queue?.current?.queueItemId;
    final upNext = queue?.next;
    return _onQueue(
      'player_queues/next',
      const {},
      'track',
      (q) => q.copyWith(current: upNext, currentIndex: (q.currentIndex ?? -1) + 1, elapsed: 0, elapsedAt: DateTime.now()),
      (q) => q.current?.queueItemId != from || upNext == null,
    );
  }

  /// Back to the start of the track (or the one before, as MA decides).
  Future<void> previous() {
    final from = queue?.current?.queueItemId;
    return _onQueue(
      'player_queues/previous',
      const {},
      'track',
      (q) => q.copyWith(elapsed: 0, elapsedAt: DateTime.now()),
      (q) => q.current?.queueItemId != from || q.position(DateTime.now()) < 5,
    );
  }

  Future<void> seek(int seconds) => _onQueue(
    'player_queues/seek',
    {'position': seconds},
    'track',
    (q) => q.copyWith(elapsed: seconds.toDouble(), elapsedAt: DateTime.now()),
    (q) => (q.position(DateTime.now()) - seconds).abs() < 4,
  );

  Future<void> setShuffle(bool on) =>
      _onQueue('player_queues/shuffle', {'shuffle_enabled': on}, 'shuffle', (q) => q.copyWith(shuffle: on), (q) => q.shuffle == on);

  Future<void> cycleRepeat() {
    final next = switch (queue?.repeat) {
      'off' => 'all',
      'all' => 'one',
      _ => 'off',
    };
    return _onQueue('player_queues/repeat', {'repeat_mode': next}, 'repeat', (q) => q.copyWith(repeat: next), (q) => q.repeat == next);
  }

  Future<List<MaQueueItem>> upcoming({int limit = 30}) async {
    final q = queue;
    if (q == null) return const [];
    final r = await _cmd('player_queues/items', {'queue_id': q.id, 'limit': limit, 'offset': (q.currentIndex ?? -1) + 1});
    return [for (final x in (r as List? ?? const [])) ?MaQueueItem.tryParse(x)];
  }

  Future<void> playQueueItem(MaQueueItem item) => _onQueue(
    'player_queues/play_index',
    {'index': item.queueItemId},
    'track',
    (q) => q.copyWith(current: item, state: 'playing', elapsed: 0, elapsedAt: DateTime.now()),
    (q) => q.current?.queueItemId == item.queueItemId,
  );
  Future<void> removeQueueItem(String queueItemId) => _cmd('player_queues/delete_item', {'queue_id': _queueId, 'item_id_or_index': queueItemId});

  /// Drops what's coming up, keeping the current track playing.
  Future<void> clearUpcoming() async {
    for (final item in await upcoming(limit: 500)) {
      await removeQueueItem(item.queueItemId);
    }
  }

  // ---------------------------------------------------------------- volume

  Future<void> setVolume(String playerId, int v) => _playerLayer.run(
    [OptimisticChange(playerId, slot: 'volume', patch: (p) => p.copyWith(volume: v), confirmed: (p) => ((p.volume ?? -10) - v).abs() <= 1)],
    () => _cmd('players/cmd/volume_set', {'player_id': playerId, 'volume_level': v}),
  );

  /// Moves every speaker in the group by the same amount (MA scales them
  /// its own way, so any move counts as confirmation).
  Future<void> setGroupVolume(int v) async {
    final on = active;
    if (on.isEmpty) return;
    if (on.length == 1) return setVolume(on.first.id, v);
    final avg = groupVolume;
    await _playerLayer.run(
      [
        for (final p in on)
          if (((p.volume ?? 0) + v - avg).clamp(0, 100) case final want when want != p.volume)
            OptimisticChange(p.id, slot: 'volume', patch: (x) => x.copyWith(volume: want), confirmed: (x) => x.volume != p.volume),
      ],
      () => _cmd('players/cmd/group_volume', {'player_id': on.first.id, 'volume_level': v}),
    );
  }

  int get groupVolume {
    final on = active.where((p) => p.volume != null).toList();
    if (on.isEmpty) return 0;
    return (on.fold<int>(0, (a, p) => a + p.volume!) / on.length).round();
  }

  /// Shows [t]'s group as exactly [members] (leader first) while [call]
  /// changes it in MA.
  Future<void> _regroup(MaPlayer t, Set<String> members, Future<void> Function() call) {
    final want = members.where((id) => id != t.id).toSet();
    Set<String> followers(MaPlayer p) => p.groupMembers.where((id) => id != p.id).toSet();
    return _playerLayer.run([
      OptimisticChange(
        t.id,
        slot: 'group',
        patch: (p) => p.copyWith(groupMembers: want.isEmpty ? const [] : [p.id, ...want]),
        confirmed: (p) => setEquals(followers(p), want),
      ),
    ], call);
  }

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
      await _regroup(t, on.toSet()..remove(id), () => _cmd('players/cmd/set_members', {'target_player': t.id, 'player_ids_to_remove': [id]}));
    } else {
      if (!canJoin(p)) throw StateError('${p.name} não pode tocar em grupo com ${t.name}');
      await _regroup(t, {...on, id}, () => _cmd('players/cmd/set_members', {'target_player': t.id, 'player_ids_to_add': [id]}));
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
    await _regroup(t, {t.id, ...want}, () => _cmd('players/cmd/set_members', {
      'target_player': t.id,
      if (add.isNotEmpty) 'player_ids_to_add': add,
      if (remove.isNotEmpty) 'player_ids_to_remove': remove,
    }));
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
