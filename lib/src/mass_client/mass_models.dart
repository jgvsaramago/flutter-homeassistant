/// Models for the Music Assistant server API — schemas confirmed live
/// against a real server (`GET /api-docs/schemas.json` on the MA instance
/// itself, schema_version 31) rather than guessed from memory. Only the
/// fields the Music sheet actually reads are modelled; MA's real `Player`/
/// `PlayerQueue`/`Track` objects carry far more (grouping, DSP, streaming
/// details, ...) that this app has no use for yet.
library;

enum MassPlaybackState { idle, paused, playing, unknown }

MassPlaybackState _parsePlaybackState(String? value) =>
    MassPlaybackState.values.firstWhere((s) => s.name == value, orElse: () => MassPlaybackState.unknown);

class MassPlayer {
  const MassPlayer({
    required this.playerId,
    required this.name,
    required this.available,
    required this.playbackState,
    required this.powered,
    required this.volumeLevel,
    required this.volumeMuted,
    required this.supportedFeatures,
    required this.groupMembers,
    required this.canGroupWith,
  });

  final String playerId;
  final String name;
  final bool available;
  final MassPlaybackState playbackState;

  /// Null for players with no concept of power (a group player, say).
  final bool? powered;
  final int? volumeLevel;
  final bool? volumeMuted;

  /// Raw `PlayerFeature` enum values (`"pause"`, `"volume_set"`,
  /// `"next_previous"`, ...) — kept as strings rather than a mirrored Dart
  /// enum since the sheet only ever checks membership.
  final Set<String> supportedFeatures;

  /// Other player_ids currently synced to this one (the Outputs view's
  /// "Grupo" — this player is always its own group's implicit leader).
  final Set<String> groupMembers;

  /// Other player_ids this one is *able* to group with — the Outputs
  /// view's "Disponíveis" list is exactly this set.
  final Set<String> canGroupWith;

  bool get canPlayPause => supportedFeatures.contains('pause');
  bool get canSkip => supportedFeatures.contains('next_previous');
  bool get canSetVolume => supportedFeatures.contains('volume_set');
  bool get canPower => supportedFeatures.contains('power');

  factory MassPlayer.fromJson(Map<String, dynamic> json) => MassPlayer(
    playerId: json['player_id'] as String,
    name: json['name'] as String? ?? json['player_id'] as String,
    available: json['available'] as bool? ?? false,
    playbackState: _parsePlaybackState(json['playback_state'] as String?),
    powered: json['powered'] as bool?,
    volumeLevel: (json['volume_level'] as num?)?.toInt(),
    volumeMuted: json['volume_muted'] as bool?,
    supportedFeatures: (json['supported_features'] as List? ?? const []).cast<String>().toSet(),
    groupMembers: (json['group_members'] as List? ?? const []).cast<String>().toSet(),
    canGroupWith: (json['can_group_with'] as List? ?? const []).cast<String>().toSet(),
  );
}

/// A `MediaItemImage` — never used directly as a URL (MA images are
/// generally provider-hosted, not publicly fetchable), always resolved via
/// `MassWebSocketClient.imageUrl`.
class MassImage {
  const MassImage({required this.path, required this.provider, required this.remotelyAccessible});

  final String path;
  final String provider;
  final bool remotelyAccessible;

  factory MassImage.fromJson(Map<String, dynamic> json) => MassImage(
    path: json['path'] as String,
    provider: json['provider'] as String,
    remotelyAccessible: json['remotely_accessible'] as bool? ?? false,
  );
}

/// One entry in a player's queue — deliberately reads only the queue item's
/// own top-level `image` field rather than descending into the nested
/// `media_item.metadata.images`, which is a much deeper structure this app
/// doesn't otherwise need.
class MassQueueItem {
  const MassQueueItem({required this.name, required this.duration, this.image, this.artist, this.album});

  final String name;
  final int? duration;
  final MassImage? image;
  final String? artist;
  final String? album;

  factory MassQueueItem.fromJson(Map<String, dynamic> json) {
    final mediaItem = (json['media_item'] as Map?)?.cast<String, dynamic>();
    final artists = (mediaItem?['artists'] as List?)?.cast<dynamic>();
    final firstArtist = artists != null && artists.isNotEmpty ? (artists.first as Map).cast<String, dynamic>() : null;
    final album = (mediaItem?['album'] as Map?)?.cast<String, dynamic>();
    final imageJson = (json['image'] as Map?)?.cast<String, dynamic>();

    return MassQueueItem(
      name: json['name'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt(),
      image: imageJson == null ? null : MassImage.fromJson(imageJson),
      artist: firstArtist?['name'] as String?,
      album: album?['name'] as String?,
    );
  }
}

/// The first `metadata.images` entry, if any — the common artwork location
/// for every full media item (Playlist/Radio/Artist/Album/Track) alike,
/// unlike `QueueItem`'s own flat `image` field.
MassImage? _firstImage(Map<String, dynamic> json) {
  final metadata = (json['metadata'] as Map?)?.cast<String, dynamic>();
  final images = (metadata?['images'] as List?)?.cast<dynamic>();
  if (images == null || images.isEmpty) return null;
  return MassImage.fromJson((images.first as Map).cast<String, dynamic>());
}

String? _firstArtistName(Map<String, dynamic> json) {
  final artists = (json['artists'] as List?)?.cast<dynamic>();
  if (artists == null || artists.isEmpty) return null;
  return (artists.first as Map).cast<String, dynamic>()['name'] as String?;
}

/// Every provider domain (`"spotify"`, `"builtin"`, ...) a library item is
/// backed by. A library item's own `uri` is always `library://<type>/<id>` —
/// the library's own internal reference, not the source provider — so this
/// is the only way to tell what actually provides a given playlist/track.
Set<String> _providerDomains(Map<String, dynamic> json) {
  final mappings = (json['provider_mappings'] as List?)?.cast<dynamic>();
  if (mappings == null) return const {};
  return mappings.map((m) => (m as Map).cast<String, dynamic>()['provider_domain'] as String?).whereType<String>().toSet();
}

/// One row/card in a library browse view — a track, radio station,
/// playlist, artist or album, reduced to just what a tap-to-play (or, for
/// artists/albums, tap-to-play-everything-by) card needs: a name, the URI
/// `player_queues/play_media` plays it by, an optional subtitle (a track or
/// album's artist), and optional artwork.
class MassBrowseItem {
  const MassBrowseItem({required this.name, required this.uri, this.subtitle, this.image, this.duration, this.providerDomains = const {}, this.mediaType});

  final String name;
  final String uri;
  final String? subtitle;
  final MassImage? image;

  /// Track length in seconds — only ever populated for tracks (playlist
  /// rows need it for the trailing "4:12" column); every other browse type
  /// leaves it null.
  final int? duration;

  /// Source provider domains backing this item (`"spotify"`, `"builtin"`,
  /// a local filesystem provider, ...) — see [_providerDomains].
  final Set<String> providerDomains;

  /// MA's own `MediaType` string (`"track"`, `"album"`, `"artist"`,
  /// `"playlist"`, `"radio"`, `"genre"`) — only populated where the item
  /// came from a mixed-type listing ([fromMediaJson]/[fromGenreJson]) that
  /// needs it to decide how to handle a tap; every type-specific factory
  /// already knows its own type by construction and leaves this null.
  final String? mediaType;

  factory MassBrowseItem.fromTrackJson(Map<String, dynamic> json) => MassBrowseItem(
    name: json['name'] as String? ?? '',
    uri: json['uri'] as String? ?? '',
    subtitle: _firstArtistName(json),
    image: _firstImage(json),
    duration: (json['duration'] as num?)?.toInt(),
    providerDomains: _providerDomains(json),
  );

  factory MassBrowseItem.fromRadioJson(Map<String, dynamic> json) => MassBrowseItem(
    name: json['name'] as String? ?? '',
    uri: json['uri'] as String? ?? '',
    image: _firstImage(json),
    providerDomains: _providerDomains(json),
  );

  factory MassBrowseItem.fromPlaylistJson(Map<String, dynamic> json) => MassBrowseItem(
    name: json['name'] as String? ?? '',
    uri: json['uri'] as String? ?? '',
    image: _firstImage(json),
    providerDomains: _providerDomains(json),
  );

  factory MassBrowseItem.fromArtistJson(Map<String, dynamic> json) => MassBrowseItem(
    name: json['name'] as String? ?? '',
    uri: json['uri'] as String? ?? '',
    image: _firstImage(json),
    providerDomains: _providerDomains(json),
  );

  factory MassBrowseItem.fromAlbumJson(Map<String, dynamic> json) => MassBrowseItem(
    name: json['name'] as String? ?? '',
    uri: json['uri'] as String? ?? '',
    subtitle: _firstArtistName(json),
    image: _firstImage(json),
    providerDomains: _providerDomains(json),
  );

  /// A genre from `music/genres/library_items` — no artwork, just a name
  /// and the `library://genre/<id>` uri `music/genres/overview` browses by.
  factory MassBrowseItem.fromGenreJson(Map<String, dynamic> json) =>
      MassBrowseItem(name: json['name'] as String? ?? '', uri: json['uri'] as String? ?? '', mediaType: 'genre');

  /// One item inside a `RecommendationFolder` (from `music/recommendations`
  /// or `music/genres/overview`) — these are full media objects but of
  /// whatever type the folder happens to hold, so dispatch on the server's
  /// own `media_type` to the matching type-specific factory, then stamp the
  /// type back on so callers rendering a mixed folder know what a tap means.
  factory MassBrowseItem.fromMediaJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String?;
    final item = switch (mediaType) {
      'track' => MassBrowseItem.fromTrackJson(json),
      'album' => MassBrowseItem.fromAlbumJson(json),
      'artist' => MassBrowseItem.fromArtistJson(json),
      'radio' => MassBrowseItem.fromRadioJson(json),
      'genre' => MassBrowseItem.fromGenreJson(json),
      _ => MassBrowseItem.fromPlaylistJson(json),
    };
    return MassBrowseItem(
      name: item.name,
      uri: item.uri,
      subtitle: item.subtitle,
      image: item.image,
      duration: item.duration,
      providerDomains: item.providerDomains,
      mediaType: mediaType ?? 'playlist',
    );
  }
}

/// One shelf of a Spotify-style home feed — `music/recommendations` returns
/// several of these ("Recently played", "Favorite playlists", ...) and
/// `music/genres/overview` returns them scoped to one genre.
class MassRecommendationFolder {
  const MassRecommendationFolder({required this.name, required this.translationKey, required this.items});

  final String name;

  /// MA's stable identifier for well-known folders (`"recently_played"`,
  /// `"favorite_playlists"`, ...) — lets the UI show its own localized
  /// title instead of the server's English `name`, for folders it recognizes.
  final String? translationKey;
  final List<MassBrowseItem> items;

  factory MassRecommendationFolder.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List?)?.cast<dynamic>() ?? const [];
    return MassRecommendationFolder(
      name: json['name'] as String? ?? '',
      translationKey: json['translation_key'] as String?,
      items: items.map((i) => MassBrowseItem.fromMediaJson((i as Map).cast<String, dynamic>())).toList(),
    );
  }
}

class MassPlayerQueue {
  const MassPlayerQueue({
    required this.queueId,
    required this.displayName,
    required this.state,
    required this.elapsedTime,
    required this.shuffleEnabled,
    required this.repeatMode,
    this.currentItem,
  });

  final String queueId;

  /// The name of whatever's loaded — a playlist, an album, a radio station —
  /// shown in the sheet header as "A tocar de" plus this name.
  final String displayName;
  final MassPlaybackState state;
  final double elapsedTime;
  final bool shuffleEnabled;

  /// Raw `RepeatMode` value: `"off"`, `"one"` or `"all"`.
  final String repeatMode;
  final MassQueueItem? currentItem;

  factory MassPlayerQueue.fromJson(Map<String, dynamic> json) {
    final currentItemJson = (json['current_item'] as Map?)?.cast<String, dynamic>();
    return MassPlayerQueue(
      queueId: json['queue_id'] as String,
      displayName: json['display_name'] as String? ?? '',
      state: _parsePlaybackState(json['state'] as String?),
      elapsedTime: (json['elapsed_time'] as num?)?.toDouble() ?? 0,
      shuffleEnabled: json['shuffle_enabled'] as bool? ?? false,
      repeatMode: json['repeat_mode'] as String? ?? 'off',
      currentItem: currentItemJson == null ? null : MassQueueItem.fromJson(currentItemJson),
    );
  }
}
