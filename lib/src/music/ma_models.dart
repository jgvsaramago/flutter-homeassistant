/// Music Assistant data as the screen uses it, parsed from MA's own JSON
/// (server 2.10, schema 65 — shapes checked against the live server).
library;

/// One image of an item. Remote ones (Spotify's CDN…) load straight from
/// [path]; local ones go through MA's image proxy by [proxyId].
class MaImage {
  const MaImage({required this.path, required this.remote, this.proxyId});

  final String path;
  final bool remote;
  final String? proxyId;

  static MaImage? fromItem(Map<String, dynamic>? item) {
    if (item == null) return null;
    final direct = item['image'];
    if (direct is Map) return _parse(direct.cast<String, dynamic>());
    final images = (item['metadata'] as Map?)?['images'];
    if (images is List) {
      final maps = images.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      final thumb = maps.where((m) => m['type'] == 'thumb').firstOrNull ?? maps.firstOrNull;
      if (thumb != null) return _parse(thumb);
    }
    final album = item['album'];
    if (album is Map) return fromItem(album.cast<String, dynamic>());
    return null;
  }

  static MaImage? _parse(Map<String, dynamic> m) {
    final path = m['path'] as String?;
    if (path == null || path.isEmpty) return null;
    return MaImage(path: path, remote: m['remotely_accessible'] == true, proxyId: m['proxy_id'] as String?);
  }
}

/// `track`, `album`, `artist`, `playlist`, `radio`, `podcast`,
/// `podcast_episode`… — MA's media types, kept as its strings.
class MaItem {
  const MaItem({
    required this.uri,
    required this.mediaType,
    required this.name,
    required this.itemId,
    required this.provider,
    this.artists = const [],
    this.albumName,
    this.albumUri,
    this.owner,
    this.year,
    this.duration,
    this.favorite = false,
    this.image,
    this.domain = '',
  });

  final String uri;
  final String mediaType;
  final String name;
  final String itemId;
  final String provider;
  final List<({String name, String uri, String itemId, String provider})> artists;
  final String? albumName;
  final String? albumUri;
  final String? owner;
  final int? year;
  final int? duration;
  final bool favorite;
  final MaImage? image;

  String get artistNames => artists.map((a) => a.name).join(', ');
  bool get isLibrary => provider == 'library';

  /// Where it streams from, for the coloured dot: `spotify`, `apple_music`,
  /// `tunein`, `radiobrowser`, `filesystem_local`… — a library item's own
  /// provider is just `library`, so this reads its first mapping.
  final String domain;

  MaItem copyWith({bool? favorite}) => MaItem(
    uri: uri,
    mediaType: mediaType,
    name: name,
    itemId: itemId,
    provider: provider,
    artists: artists,
    albumName: albumName,
    albumUri: albumUri,
    owner: owner,
    year: year,
    duration: duration,
    favorite: favorite ?? this.favorite,
    image: image,
    domain: domain,
  );

  static MaItem? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    final uri = m['uri'] as String?;
    final name = m['name'] as String?;
    if (uri == null || name == null) return null;
    final artists = [
      for (final a in (m['artists'] as List? ?? const []).whereType<Map>())
        (
          name: a['name'] as String? ?? '',
          uri: a['uri'] as String? ?? '',
          itemId: '${a['item_id'] ?? ''}',
          provider: a['provider'] as String? ?? '',
        ),
    ];
    final album = (m['album'] as Map?)?.cast<String, dynamic>();
    final owner = m['owner'] as String? ?? m['publisher'] as String?;
    final mapping = (m['provider_mappings'] as List?)?.whereType<Map>().firstOrNull;
    final provider = m['provider'] as String? ?? '';
    return MaItem(
      uri: uri,
      mediaType: m['media_type'] as String? ?? '',
      name: name,
      itemId: '${m['item_id'] ?? ''}',
      provider: provider,
      domain: mapping?['provider_domain'] as String? ?? provider.split('--').first,
      artists: artists,
      albumName: album?['name'] as String?,
      albumUri: album?['uri'] as String?,
      owner: owner,
      year: (m['year'] as num?)?.toInt(),
      duration: (m['duration'] as num?)?.toInt(),
      favorite: m['favorite'] == true,
      image: MaImage.fromItem(m),
    );
  }

  static List<MaItem> list(Object? raw) => [
    for (final x in (raw is List ? raw : const [])) ?tryParse(x),
  ];
}

class MaPlayer {
  const MaPlayer({
    required this.id,
    required this.name,
    required this.available,
    required this.volume,
    required this.groupMembers,
    required this.canGroupWith,
    required this.model,
    required this.manufacturer,
    required this.provider,
    this.activeSource,
    this.syncedTo,
    this.activeGroup,
  });

  final String id;
  final String name;
  final bool available;
  final int? volume;
  final List<String> groupMembers;
  final List<String> canGroupWith;
  final String model;
  final String manufacturer;
  final String provider;
  final String? activeSource;
  final String? syncedTo;
  final String? activeGroup;

  /// The queue this player plays from.
  String get queueId => activeSource ?? id;

  MaPlayer copyWith({int? volume, List<String>? groupMembers}) => MaPlayer(
    id: id,
    name: name,
    available: available,
    volume: volume ?? this.volume,
    groupMembers: groupMembers ?? this.groupMembers,
    canGroupWith: canGroupWith,
    model: model,
    manufacturer: manufacturer,
    provider: provider,
    activeSource: activeSource,
    syncedTo: syncedTo,
    activeGroup: activeGroup,
  );

  static MaPlayer? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    final id = m['player_id'] as String?;
    if (id == null) return null;
    if (m['enabled'] == false || m['hide_in_ui'] == true || m['hide_player_in_ui'] == true) return null;
    final type = m['type'] as String? ?? 'player';
    if (type != 'player' && type != 'group') return null;
    final info = (m['device_info'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MaPlayer(
      id: id,
      name: m['display_name'] as String? ?? m['name'] as String? ?? id,
      available: m['available'] == true,
      volume: (m['volume_level'] as num?)?.round(),
      groupMembers: [for (final x in (m['group_members'] as List? ?? const [])) '$x'],
      canGroupWith: [for (final x in (m['can_group_with'] as List? ?? const [])) '$x'],
      model: info['model'] as String? ?? '',
      manufacturer: info['manufacturer'] as String? ?? '',
      provider: m['provider'] as String? ?? '',
      activeSource: m['active_source'] as String?,
      syncedTo: m['synced_to'] as String?,
      activeGroup: m['active_group'] as String?,
    );
  }
}

class MaQueueItem {
  const MaQueueItem({required this.queueItemId, required this.name, this.duration, this.media, this.image});

  final String queueItemId;
  final String name;
  final int? duration;
  final MaItem? media;
  final MaImage? image;

  static MaQueueItem? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    final id = m['queue_item_id'] as String?;
    if (id == null) return null;
    final media = MaItem.tryParse(m['media_item']);
    return MaQueueItem(
      queueItemId: id,
      name: m['name'] as String? ?? media?.name ?? '',
      duration: (m['duration'] as num?)?.toInt() ?? media?.duration,
      media: media,
      image: MaImage.fromItem(m) ?? media?.image,
    );
  }
}

class MaQueue {
  const MaQueue({
    required this.id,
    required this.state,
    required this.shuffle,
    required this.repeat,
    required this.elapsed,
    required this.elapsedAt,
    required this.itemCount,
    this.currentIndex,
    this.current,
    this.next,
  });

  final String id;

  /// `playing`, `paused`, `idle`.
  final String state;
  final bool shuffle;

  /// `off`, `one`, `all`.
  final String repeat;
  final double elapsed;
  final DateTime elapsedAt;
  final int itemCount;
  final int? currentIndex;
  final MaQueueItem? current;
  final MaQueueItem? next;

  bool get playing => state == 'playing';

  /// Where playback is now, moving on from the last report while playing.
  double position(DateTime now) {
    if (!playing) return elapsed;
    final p = elapsed + now.difference(elapsedAt).inMilliseconds / 1000;
    final d = current?.duration;
    return d != null && d > 0 ? p.clamp(0, d.toDouble()) : p;
  }

  MaQueue withElapsed(double seconds) => copyWith(elapsed: seconds, elapsedAt: DateTime.now());

  MaQueue copyWith({String? state, bool? shuffle, String? repeat, double? elapsed, DateTime? elapsedAt, int? currentIndex, MaQueueItem? current}) => MaQueue(
    id: id,
    state: state ?? this.state,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    elapsed: elapsed ?? this.elapsed,
    elapsedAt: elapsedAt ?? this.elapsedAt,
    itemCount: itemCount,
    currentIndex: currentIndex ?? this.currentIndex,
    current: current ?? this.current,
    next: next,
  );

  static MaQueue? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    final id = m['queue_id'] as String?;
    if (id == null) return null;
    final at = (m['elapsed_time_last_updated'] as num?)?.toDouble();
    return MaQueue(
      id: id,
      state: m['state'] as String? ?? 'idle',
      shuffle: m['shuffle_enabled'] == true,
      repeat: m['repeat_mode'] as String? ?? 'off',
      elapsed: (m['elapsed_time'] as num?)?.toDouble() ?? 0,
      elapsedAt: at == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch((at * 1000).round()),
      itemCount: (m['items'] as num?)?.toInt() ?? 0,
      currentIndex: (m['current_index'] as num?)?.toInt(),
      current: MaQueueItem.tryParse(m['current_item']),
      next: MaQueueItem.tryParse(m['next_item']),
    );
  }
}

/// `music/search`'s results.
class MaSearchResults {
  const MaSearchResults({
    this.artists = const [],
    this.albums = const [],
    this.tracks = const [],
    this.playlists = const [],
    this.radios = const [],
    this.podcasts = const [],
  });

  final List<MaItem> artists;
  final List<MaItem> albums;
  final List<MaItem> tracks;
  final List<MaItem> playlists;
  final List<MaItem> radios;
  final List<MaItem> podcasts;

  bool get isEmpty => artists.isEmpty && albums.isEmpty && tracks.isEmpty && playlists.isEmpty && radios.isEmpty && podcasts.isEmpty;

  factory MaSearchResults.fromJson(Object? raw) {
    final m = raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};
    return MaSearchResults(
      artists: MaItem.list(m['artists']),
      albums: MaItem.list(m['albums']),
      tracks: MaItem.list(m['tracks']),
      playlists: MaItem.list(m['playlists']),
      radios: MaItem.list(m['radio']),
      podcasts: MaItem.list(m['podcasts']),
    );
  }
}
