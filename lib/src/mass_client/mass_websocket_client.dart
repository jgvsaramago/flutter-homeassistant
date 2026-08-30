import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'mass_connection_config.dart';
import 'mass_exceptions.dart';
import 'mass_models.dart';

enum MassConnectionState { disconnected, connecting, authenticating, connected, error }

/// A `player_updated`/`queue_updated`/... push from the server. MA
/// auto-subscribes every authenticated client to all events (unlike HA,
/// there's no separate `subscribe_events` command).
class MassEvent {
  const MassEvent({required this.event, this.objectId, this.data});

  final String event;

  /// player_id, queue_id or provider id, depending on [event].
  final String? objectId;
  final dynamic data;
}

/// Low-level client for the Music Assistant websocket API.
///
/// Protocol confirmed live against a real server (schema_version 31, see
/// `GET /api-docs/commands.json` and `/api-docs/schemas.json` on the MA
/// instance itself) rather than assumed from memory:
/// - The server sends an unprompted `ServerInfoMessage` the instant the
///   socket opens — this client treats "first message received" as that
///   greeting and replies with `auth` immediately, rather than parsing it.
/// - Every message after that is one of: an event (`"event"` key present),
///   or a result for a command this client sent, correlated by
///   `message_id` — which MA sends as a *string*, unlike HA's integer ids.
/// - A successful `auth` implicitly subscribes the connection to every
///   event for as long as it stays open.
class MassWebSocketClient {
  MassWebSocketClient();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  MassConnectionConfig? _config;
  bool _greeted = false;

  int _messageId = 1;
  final Map<String, Completer<dynamic>> _pendingCommands = {};

  /// Some commands (`playlist_tracks`, an `AsyncGenerator` on the server
  /// side) stream their result across several `partial: true` messages
  /// before a final non-partial one — this buffers those by message id
  /// until the final message lets the pending command resolve with the
  /// whole accumulated list.
  final Map<String, List<dynamic>> _partialResults = {};
  static const _authMessageId = '_auth';

  final _connectionStateController = StreamController<MassConnectionState>.broadcast();
  final _eventsController = StreamController<MassEvent>.broadcast();

  MassConnectionState _state = MassConnectionState.disconnected;
  MassConnectionState get state => _state;

  /// Yields the *current* state first, then every subsequent change — see
  /// the identical comment on `HaWebSocketClient.connectionState`, the bug
  /// this mirrors: a plain `.stream` getter on a broadcast controller
  /// leaves a listener that subscribes after the connection has already
  /// settled stuck showing nothing until the next real transition.
  Stream<MassConnectionState> get connectionState async* {
    yield _state;
    yield* _connectionStateController.stream;
  }

  Stream<MassEvent> get events => _eventsController.stream;

  void _setState(MassConnectionState next) {
    _state = next;
    _connectionStateController.add(next);
  }

  Future<void> connect(MassConnectionConfig config) async {
    await disconnect();
    _config = config;
    _greeted = false;
    _setState(MassConnectionState.connecting);
    debugPrint('[mass websocket] connecting to ${config.webSocketUri}...');

    final channel = WebSocketChannel.connect(config.webSocketUri);
    _channel = channel;

    final authCompleter = Completer<void>();
    _pendingCommands[_authMessageId] = Completer<dynamic>()
      ..future.then((_) {
        if (!authCompleter.isCompleted) authCompleter.complete();
      }, onError: (Object error) {
        if (!authCompleter.isCompleted) authCompleter.completeError(error);
      });

    _channelSubscription = channel.stream.listen(
      _handleMessage,
      onError: (Object error) {
        debugPrint('[mass websocket] connection error: $error');
        _setState(MassConnectionState.error);
        if (!authCompleter.isCompleted) authCompleter.completeError(MassConnectionException(error.toString()));
        _failPendingCommands(MassConnectionException(error.toString()));
      },
      onDone: () {
        _setState(MassConnectionState.disconnected);
        if (!authCompleter.isCompleted) {
          authCompleter.completeError(const MassConnectionException('Connection closed before authentication completed'));
        }
        _failPendingCommands(const MassConnectionException('Connection closed'));
      },
      cancelOnError: false,
    );

    try {
      await channel.ready;
    } catch (e) {
      _setState(MassConnectionState.error);
      throw MassConnectionException('Failed to open websocket: $e');
    }

    _setState(MassConnectionState.authenticating);
    try {
      await authCompleter.future;
      _setState(MassConnectionState.connected);
      debugPrint('[mass websocket] connected and authenticated successfully');
    } catch (e) {
      debugPrint('[mass websocket] authentication failed: $e');
      rethrow;
    }
  }

  void _handleMessage(dynamic raw) {
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (!_greeted) {
      _greeted = true;
      // The server's unprompted greeting — send auth the instant it arrives.
      final config = _config;
      if (config != null) {
        _send({
          'command': 'auth',
          'message_id': _authMessageId,
          'args': {'token': config.accessToken},
        });
      }
      return;
    }

    if (message.containsKey('event')) {
      _eventsController.add(MassEvent(event: message['event'] as String, objectId: message['object_id'] as String?, data: message['data']));
      return;
    }

    final id = message['message_id'] as String?;
    if (id == null) return;

    if (message.containsKey('error_code')) {
      _partialResults.remove(id);
      final completer = _pendingCommands.remove(id);
      completer?.completeError(MassCommandException(message['error_code'] as int?, message['details'] as String? ?? 'Command failed'));
      return;
    }

    final isPartial = message['partial'] as bool? ?? false;
    if (isPartial) {
      final chunk = message['result'];
      if (chunk is List) _partialResults.putIfAbsent(id, () => []).addAll(chunk);
      return;
    }

    final completer = _pendingCommands.remove(id);
    if (completer == null) return;

    final buffered = _partialResults.remove(id);
    final result = message['result'];
    if (buffered != null) {
      if (result is List) buffered.addAll(result);
      completer.complete(buffered);
    } else {
      completer.complete(result);
    }
  }

  void _failPendingCommands(Object error) {
    for (final completer in _pendingCommands.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pendingCommands.clear();
    _partialResults.clear();
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) throw const MassConnectionException('Not connected');
    channel.sink.add(jsonEncode(message));
  }

  Future<dynamic> _sendCommand(String command, [Map<String, dynamic>? args]) {
    final id = (_messageId++).toString();
    final completer = Completer<dynamic>();
    _pendingCommands[id] = completer;
    _send({'command': command, 'message_id': id, if (args != null) 'args': args});
    return completer.future;
  }

  Future<List<MassPlayer>> getAllPlayers() async {
    final result = await _sendCommand('players/all') as List;
    return result.cast<Map<String, dynamic>>().map(MassPlayer.fromJson).toList();
  }

  /// Null when the player has no Music-Assistant-native queue (e.g. it's
  /// idle, or playing from a source MA doesn't manage).
  Future<MassPlayerQueue?> getActiveQueue(String playerId) async {
    try {
      final result = await _sendCommand('player_queues/get_active_queue', {'player_id': playerId});
      return result == null ? null : MassPlayerQueue.fromJson(result as Map<String, dynamic>);
    } on MassCommandException {
      return null;
    }
  }

  Future<void> playerCommand(String command, String playerId) => _sendCommand('players/cmd/$command', {'player_id': playerId});

  Future<void> setVolume(String playerId, int level) => _sendCommand('players/cmd/volume_set', {'player_id': playerId, 'volume_level': level});

  Future<void> seekQueue(String queueId, double positionSeconds) =>
      _sendCommand('player_queues/seek', {'queue_id': queueId, 'position': positionSeconds.round()});

  Future<void> setPower(String playerId, bool powered) => _sendCommand('players/cmd/power', {'player_id': playerId, 'powered': powered});

  Future<void> setQueueShuffle(String queueId, bool enabled) => _sendCommand('player_queues/shuffle', {'queue_id': queueId, 'shuffle_enabled': enabled});

  /// [repeatMode] is MA's raw `RepeatMode` value: `"off"`, `"one"` or `"all"`.
  Future<void> setQueueRepeat(String queueId, String repeatMode) => _sendCommand('player_queues/repeat', {'queue_id': queueId, 'repeat_mode': repeatMode});

  Future<List<MassBrowseItem>> getLibraryTracks({int limit = 50}) async {
    final result = await _sendCommand('music/tracks/library_items', {'limit': limit}) as List;
    return result.cast<Map<String, dynamic>>().map(MassBrowseItem.fromTrackJson).toList();
  }

  Future<List<MassBrowseItem>> getLibraryRadios({int limit = 50}) async {
    final result = await _sendCommand('music/radios/library_items', {'limit': limit}) as List;
    return result.cast<Map<String, dynamic>>().map(MassBrowseItem.fromRadioJson).toList();
  }

  Future<List<MassBrowseItem>> getLibraryPlaylists({int limit = 20}) async {
    final result = await _sendCommand('music/playlists/library_items', {'limit': limit}) as List;
    return result.cast<Map<String, dynamic>>().map(MassBrowseItem.fromPlaylistJson).toList();
  }

  Future<List<MassBrowseItem>> getLibraryArtists({int limit = 20}) async {
    final result = await _sendCommand('music/artists/library_items', {'limit': limit}) as List;
    return result.cast<Map<String, dynamic>>().map(MassBrowseItem.fromArtistJson).toList();
  }

  Future<List<MassBrowseItem>> getLibraryAlbums({int limit = 20}) async {
    final result = await _sendCommand('music/albums/library_items', {'limit': limit}) as List;
    return result.cast<Map<String, dynamic>>().map(MassBrowseItem.fromAlbumJson).toList();
  }

  Future<List<MassBrowseItem>> getGenres({int limit = 20}) async {
    final result = await _sendCommand('music/genres/library_items', {'limit': limit, 'hide_empty': true}) as List;
    return result.cast<Map<String, dynamic>>().map(MassBrowseItem.fromGenreJson).toList();
  }

  /// Cross-media-type shelves for a genre ("Playlists", "Top tracks", ...) —
  /// the Explorar "Por género" shelf's own home screen once you tap in.
  Future<List<MassRecommendationFolder>> getGenreOverview(MassBrowseItem genre, {int limit = 10}) async {
    final parsed = _parseUri(genre.uri);
    if (parsed == null) return const [];
    final result = await _sendCommand('music/genres/overview', {'item_id': parsed.itemId, 'provider_instance_id_or_domain': parsed.provider, 'limit': limit}) as List;
    return result.cast<Map<String, dynamic>>().map(MassRecommendationFolder.fromJson).toList();
  }

  /// MA's own Spotify-style home feed — "Recently played", "Favorite
  /// playlists", "Random artists", ... — each folder pre-populated by the
  /// server, no client-side guesswork about what counts as a suggestion.
  Future<List<MassRecommendationFolder>> getRecommendations() async {
    final result = await _sendCommand('music/recommendations') as List;
    return result.cast<Map<String, dynamic>>().map(MassRecommendationFolder.fromJson).toList();
  }

  /// A flat, mixed-type result list for the Explorar search box — tracks,
  /// albums, artists and playlists interleaved by category rather than
  /// split into `SearchResults`' own separate arrays, since the sheet's
  /// search view is one simple list, not a categorized results page.
  Future<List<MassBrowseItem>> search(String query, {int limit = 10}) async {
    final result = await _sendCommand('music/search', {'search_query': query, 'limit': limit}) as Map;
    final json = result.cast<String, dynamic>();
    List<Map<String, dynamic>> listOf(String key) => ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    return [
      ...listOf('tracks').map(MassBrowseItem.fromTrackJson),
      ...listOf('albums').map(MassBrowseItem.fromAlbumJson),
      ...listOf('artists').map(MassBrowseItem.fromArtistJson),
      ...listOf('playlists').map(MassBrowseItem.fromPlaylistJson),
      ...listOf('radio').map(MassBrowseItem.fromRadioJson),
    ];
  }

  /// A playlist's own tracks, in order — `item_id`/`provider` come from the
  /// playlist's own `uri` (`<provider>://playlist/<item_id>`), since that's
  /// the only identifying info a [MassBrowseItem] carries.
  Future<List<MassBrowseItem>> getPlaylistTracks(String playlistUri) async {
    final parsed = _parseUri(playlistUri);
    if (parsed == null) return const [];
    final result = await _sendCommand('music/playlists/playlist_tracks', {'item_id': parsed.itemId, 'provider_instance_id_or_domain': parsed.provider}) as List;
    return result.cast<Map<String, dynamic>>().map(MassBrowseItem.fromTrackJson).toList();
  }

  /// `<provider>://<media_type>/<item_id>` — every MA URI follows this
  /// shape (confirmed against real playlist/track/radio URIs from a live
  /// server), so this is the one place that parsing happens.
  ({String provider, String itemId})? _parseUri(String uri) {
    final match = RegExp(r'^([a-zA-Z0-9_]+)://[a-zA-Z0-9_]+/(.+)$').firstMatch(uri);
    if (match == null) return null;
    return (provider: match.group(1)!, itemId: match.group(2)!);
  }

  /// Adds/removes [playerId] from [targetPlayerId]'s group in one call —
  /// the primitive the Outputs view's per-speaker checkbox toggles.
  Future<void> setGroupMembership(String targetPlayerId, String playerId, bool included) => _sendCommand('players/cmd/set_members', {
    'target_player': targetPlayerId,
    if (included) 'player_ids_to_add': [playerId],
    if (!included) 'player_ids_to_remove': [playerId],
  });

  Future<void> setGroupVolume(String playerId, int level) => _sendCommand('players/cmd/group_volume', {'player_id': playerId, 'volume_level': level});

  /// Starts playing [uri] immediately on [queueId] — a MA player's own
  /// queue id is its player_id for the common (non-grouped) case, so
  /// callers with no active queue yet (an idle player has none) can still
  /// pass the player_id straight through.
  Future<void> playMedia(String queueId, String uri) => _sendCommand('player_queues/play_media', {'queue_id': queueId, 'media': uri, 'option': 'play'});

  /// Resolves a `MassImage` to something an `Image.network` can actually
  /// load. Most MA images live behind the server's own `/imageproxy` route
  /// (they're provider-hosted and often need the server's own credentials
  /// to fetch) — only images explicitly marked `remotely_accessible` with
  /// an already-public URL skip the proxy.
  String? imageUrl(MassImage? image, {int size = 300}) {
    final config = _config;
    if (image == null || config == null) return null;
    if (image.remotelyAccessible && (image.path.startsWith('http://') || image.path.startsWith('https://'))) {
      return image.path;
    }
    final base = config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/imageproxy?path=${Uri.encodeComponent(image.path)}&provider=${Uri.encodeComponent(image.provider)}&size=$size';
  }

  Future<void> disconnect() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    await _channel?.sink.close();
    _channel = null;
    _pendingCommands.clear();
    _partialResults.clear();
    _messageId = 1;
    _greeted = false;
    if (_state != MassConnectionState.disconnected) _setState(MassConnectionState.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _connectionStateController.close();
    await _eventsController.close();
  }
}
