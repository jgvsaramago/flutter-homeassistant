import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/ha_calendar_event.dart';
import '../models/ha_entity.dart';
import '../models/ha_history_point.dart';
import 'ha_connection_config.dart';
import 'ha_exceptions.dart';

enum HaConnectionState { disconnected, connecting, authenticating, connected, error }

/// Low-level client for the Home Assistant WebSocket API.
///
/// Handles the auth handshake, request/response correlation via incrementing
/// message ids, and fans out `state_changed` events to [entityUpdates].
///
/// See: https://developers.home-assistant.io/docs/api/websocket
class HaWebSocketClient {
  HaWebSocketClient();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  int _messageId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pendingCommands = {};

  final _connectionStateController = StreamController<HaConnectionState>.broadcast();
  final _entityUpdatesController = StreamController<HaEntity>.broadcast();

  HaConnectionState _state = HaConnectionState.disconnected;
  HaConnectionState get state => _state;

  /// Yields the *current* state first, then every subsequent change.
  ///
  /// [_connectionStateController] is a broadcast controller, which never
  /// replays past events to a new listener — a plain `.stream` getter would
  /// leave any listener that subscribes after the connection has already
  /// settled (Settings, opened well after app startup, is the case that
  /// actually hit this) stuck showing nothing/a stale default forever,
  /// until the next real transition happens to occur while it's watching.
  Stream<HaConnectionState> get connectionState async* {
    yield _state;
    yield* _connectionStateController.stream;
  }

  /// Emits every entity whose state changes after the initial `get_states`
  /// snapshot has been fetched by the caller.
  Stream<HaEntity> get entityUpdates => _entityUpdatesController.stream;

  void _setState(HaConnectionState next) {
    _state = next;
    _connectionStateController.add(next);
  }

  Future<void> connect(HaConnectionConfig config) async {
    await disconnect();
    _setState(HaConnectionState.connecting);
    debugPrint('[ha websocket] connecting to ${config.webSocketUri}...');

    final channel = WebSocketChannel.connect(config.webSocketUri);
    _channel = channel;

    final authCompleter = Completer<void>();
    // Distinguishes an unexpected mid-session drop (worth logging) from the
    // ordinary closure every clean disconnect() also triggers via
    // channel.sink.close() (not worth logging — it's not a failure).
    var wasConnected = false;

    _channelSubscription = channel.stream.listen(
      (raw) => _handleMessage(raw, authCompleter, config),
      onError: (Object error) {
        debugPrint('[ha websocket] connection error: $error');
        _setState(HaConnectionState.error);
        if (!authCompleter.isCompleted) {
          authCompleter.completeError(HaConnectionException(error.toString()));
        }
        _failPendingCommands(HaConnectionException(error.toString()));
      },
      onDone: () {
        if (wasConnected) debugPrint('[ha websocket] connection closed');
        _setState(HaConnectionState.disconnected);
        if (!authCompleter.isCompleted) {
          debugPrint('[ha websocket] connection closed before authentication completed');
          authCompleter.completeError(const HaConnectionException('Connection closed before authentication completed'));
        }
        _failPendingCommands(const HaConnectionException('Connection closed'));
      },
      cancelOnError: false,
    );

    try {
      await channel.ready;
    } catch (e) {
      debugPrint('[ha websocket] failed to open connection: $e');
      _setState(HaConnectionState.error);
      throw HaConnectionException('Failed to open websocket: $e');
    }

    try {
      await authCompleter.future;
      wasConnected = true;
      debugPrint('[ha websocket] connected and authenticated successfully');
    } catch (e) {
      debugPrint('[ha websocket] authentication failed: $e');
      rethrow;
    }
  }

  void _handleMessage(dynamic raw, Completer<void> authCompleter, HaConnectionConfig config) {
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (message['type']) {
      case 'auth_required':
        _setState(HaConnectionState.authenticating);
        _send({'type': 'auth', 'access_token': config.accessToken});
        break;

      case 'auth_ok':
        _setState(HaConnectionState.connected);
        if (!authCompleter.isCompleted) authCompleter.complete();
        break;

      case 'auth_invalid':
        _setState(HaConnectionState.error);
        if (!authCompleter.isCompleted) {
          authCompleter.completeError(HaAuthException(message['message'] as String? ?? 'Invalid access token'));
        }
        break;

      case 'result':
        _handleResult(message);
        break;

      case 'event':
        _handleEvent(message);
        break;

      case 'pong':
        break;
    }
  }

  void _handleResult(Map<String, dynamic> message) {
    final id = message['id'] as int?;
    if (id == null) return;
    final completer = _pendingCommands.remove(id);
    if (completer == null) return;

    final success = message['success'] as bool? ?? false;
    if (success) {
      completer.complete(message);
    } else {
      final error = (message['error'] as Map?)?.cast<String, dynamic>();
      completer.completeError(
        HaCommandException(error?['code'] as String?, error?['message'] as String? ?? 'Command failed'),
      );
    }
  }

  void _handleEvent(Map<String, dynamic> message) {
    final event = (message['event'] as Map?)?.cast<String, dynamic>();
    if (event == null) return;
    if (event['event_type'] != 'state_changed') return;

    final data = (event['data'] as Map?)?.cast<String, dynamic>();
    final newState = (data?['new_state'] as Map?)?.cast<String, dynamic>();
    if (newState == null) return;

    _entityUpdatesController.add(HaEntity.fromJson(newState));
  }

  void _failPendingCommands(Object error) {
    for (final completer in _pendingCommands.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pendingCommands.clear();
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) throw const HaConnectionException('Not connected');
    channel.sink.add(jsonEncode(message));
  }

  Future<Map<String, dynamic>> _sendCommand(Map<String, dynamic> message) {
    final id = _messageId++;
    final completer = Completer<Map<String, dynamic>>();
    _pendingCommands[id] = completer;
    _send({...message, 'id': id});
    return completer.future;
  }

  /// Subscribes to `state_changed` events. Must be called once after
  /// [connect] resolves; updates then flow through [entityUpdates].
  Future<void> subscribeToStateChanges() async {
    await _sendCommand({'type': 'subscribe_events', 'event_type': 'state_changed'});
  }

  Future<List<HaEntity>> getStates() async {
    final result = await _sendCommand({'type': 'get_states'});
    final states = (result['result'] as List).cast<Map<String, dynamic>>();
    return states.map(HaEntity.fromJson).toList();
  }

  /// Maps entity_id -> area name, resolved via the entity/device/area
  /// registries (`get_states` alone carries no room/area information).
  /// An entity's area comes from its own registry entry if set, otherwise
  /// from the area of the device it belongs to.
  Future<Map<String, String>> getAreaByEntityId() async {
    final areas = await _list('config/area_registry/list');
    final devices = await _list('config/device_registry/list');
    final entities = await _list('config/entity_registry/list');

    final areaNameById = {
      for (final area in areas)
        if (area['area_id'] is String) area['area_id'] as String: area['name'] as String? ?? 'Unknown',
    };
    final deviceAreaById = {
      for (final device in devices)
        if (device['id'] is String && device['area_id'] is String) device['id'] as String: device['area_id'] as String,
    };

    final result = <String, String>{};
    for (final entry in entities) {
      final entityId = entry['entity_id'] as String?;
      if (entityId == null) continue;
      final areaId = (entry['area_id'] as String?) ?? deviceAreaById[entry['device_id'] as String?];
      final areaName = areaId == null ? null : areaNameById[areaId];
      if (areaName != null) result[entityId] = areaName;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _list(String commandType) async {
    final result = await _sendCommand({'type': commandType});
    return (result['result'] as List).cast<Map<String, dynamic>>();
  }

  /// Fetches minimal (state + timestamp) history for a single entity between
  /// [start] and [end] (defaults to now), via `history/history_during_period`.
  /// States that aren't parseable as numbers (e.g. `unavailable`) are dropped.
  Future<List<HaHistoryPoint>> historyDuringPeriod(String entityId, {required DateTime start, DateTime? end}) async {
    final result = await _sendCommand({
      'type': 'history/history_during_period',
      'start_time': start.toUtc().toIso8601String(),
      'end_time': ?end?.toUtc().toIso8601String(),
      'entity_ids': [entityId],
      'minimal_response': true,
      'no_attributes': true,
    });

    final byEntity = (result['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final raw = (byEntity[entityId] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    final points = <HaHistoryPoint>[];
    for (final entry in raw) {
      final state = entry['s'];
      final updated = entry['lu'];
      if (state is! String || updated is! num) continue;
      final value = double.tryParse(state);
      if (value == null) continue;
      points.add(HaHistoryPoint(time: DateTime.fromMillisecondsSinceEpoch((updated * 1000).round()), value: value));
    }
    return points;
  }

  /// Fetches events for one calendar entity between [start] and [end].
  ///
  /// Goes through the `flutter_homeassistant` custom integration's own
  /// `get_calendar_events` websocket command (see
  /// custom_components/flutter_homeassistant/__init__.py) rather than HA's
  /// REST `/api/calendars/<entity_id>` endpoint directly. Two dead ends
  /// led here: dart:io's `HttpClient` is unsupported on Flutter web (throws
  /// at runtime), and switching to `package:http` traded that for a browser
  /// CORS block on the cross-origin REST call — either way, every
  /// calendar's events broke as soon as one was configured on the web
  /// build. Routing through this integration's own websocket command
  /// (already open and authenticated for every other call this client
  /// makes) sidesteps CORS entirely, since it's not a REST fetch at all.
  Future<List<HaCalendarEvent>> getCalendarEvents(String entityId, {required DateTime start, required DateTime end}) async {
    final result = await _sendCommand({
      'type': 'flutter_homeassistant/get_calendar_events',
      'entity_id': entityId,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    });
    final events = ((result['result'] as Map)['events'] as List).cast<Map<String, dynamic>>();
    return events.map(HaCalendarEvent.fromJson).toList();
  }

  /// Reads one settings key stored by the `flutter_homeassistant` custom
  /// integration (see custom_components/flutter_homeassistant/__init__.py).
  /// Returns `null` if that key was never set.
  Future<dynamic> getSettings(String key) async {
    final result = await _sendCommand({'type': 'flutter_homeassistant/get_settings', 'key': key});
    return (result['result'] as Map)['value'];
  }

  /// Persists one settings key via the `flutter_homeassistant` custom
  /// integration. [value] must be JSON-serializable (dict/list/String/num/
  /// bool/null) — passed through as-is, no pre-encoding needed.
  Future<void> setSettings(String key, dynamic value) async {
    await _sendCommand({'type': 'flutter_homeassistant/set_settings', 'key': key, 'value': value});
  }

  /// Calls a Home Assistant service, e.g. domain `light`, service `turn_on`,
  /// target `{'entity_id': 'light.kitchen'}`.
  Future<void> callService(
    String domain,
    String service, {
    Map<String, dynamic>? serviceData,
    Map<String, dynamic>? target,
  }) async {
    await _sendCommand({
      'type': 'call_service',
      'domain': domain,
      'service': service,
      'service_data': ?serviceData,
      'target': ?target,
    });
  }

  /// Fetches [entityId]'s forecast via HA's `weather.get_forecasts` service
  /// — the modern replacement for the legacy `forecast` attribute some
  /// `weather.*` entities still carry directly (that older path needs no
  /// service call at all; see `energy_forecast_provider.dart`'s own
  /// fallback for it). Unlike [callService], this is a response-returning
  /// service call (`return_response: true`), so the result comes back
  /// nested under `result.response.<entityId>.forecast` rather than being
  /// discarded.
  ///
  /// Returns each forecast entry (`{datetime, condition, temperature,
  /// templow, ...}`, shape varies slightly by weather integration) as-is;
  /// the caller decides how to read/round them. Returns an empty list for
  /// any response shape that doesn't match — an integration that doesn't
  /// support this service, for instance — rather than throwing.
  Future<List<Map<String, dynamic>>> getWeatherForecasts(String entityId, {String type = 'daily'}) async {
    final result = await _sendCommand({
      'type': 'call_service',
      'domain': 'weather',
      'service': 'get_forecasts',
      'service_data': {'type': type},
      'target': {'entity_id': entityId},
      'return_response': true,
    });
    final response = ((result['result'] as Map?)?['response'] as Map?)?.cast<String, dynamic>();
    final forecast = (response?[entityId] as Map?)?['forecast'];
    if (forecast is! List) return const [];
    return forecast.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> disconnect() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    await _channel?.sink.close();
    _channel = null;
    _pendingCommands.clear();
    _messageId = 1;
    if (_state != HaConnectionState.disconnected) _setState(HaConnectionState.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _connectionStateController.close();
    await _entityUpdatesController.close();
  }
}
