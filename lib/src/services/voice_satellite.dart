import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Where the voice pipeline is, as Linux Voice Assistant reports it.
enum SatellitePhase { idle, listening, thinking, speaking }

/// Something the conversation view shows: what HA heard, what it answered,
/// or why the pipeline gave up.
sealed class SatelliteEvent {
  const SatelliteEvent();
}

class SatelliteWake extends SatelliteEvent {
  const SatelliteWake();
}

class SatelliteHeard extends SatelliteEvent {
  const SatelliteHeard(this.text);
  final String text;
}

class SatelliteReply extends SatelliteEvent {
  const SatelliteReply(this.text);
  final String text;
}

class SatelliteError extends SatelliteEvent {
  const SatelliteError(this.reason);
  final String reason;
}

/// Client for Linux Voice Assistant's peripheral WebSocket API, which runs
/// on this same Pi (`linux-voice-assistant.service`, port 6055). LVA is the
/// ESPHome voice satellite HA talks to — it owns the mic, the wake word and
/// the speaker; this only mirrors its state on screen and lets the
/// Assistente's mic button start/stop a pipeline.
///
/// LVA isn't always running (no mic yet, or the service is stopped), so this
/// keeps retrying quietly; [available] is what the UI checks.
class VoiceSatellite {
  VoiceSatellite._();

  static final instance = VoiceSatellite._();

  static final _uri = Uri.parse('ws://127.0.0.1:6055');

  /// LVA is reachable and itself connected to HA.
  final available = ValueNotifier<bool>(false);
  final phase = ValueNotifier<SatellitePhase>(SatellitePhase.idle);
  final muted = ValueNotifier<bool>(false);

  final _events = StreamController<SatelliteEvent>.broadcast();
  Stream<SatelliteEvent> get events => _events.stream;

  WebSocketChannel? _channel;
  bool _started = false;
  bool _haConnected = false;
  var _retry = const Duration(seconds: 5);

  /// Starts the connect/retry loop; safe to call more than once. Nothing to
  /// talk to in a browser preview.
  void start() {
    if (_started || kIsWeb) return;
    _started = true;
    _connect();
  }

  Future<void> _connect() async {
    final channel = WebSocketChannel.connect(_uri);
    try {
      await channel.ready;
    } catch (_) {
      _scheduleReconnect();
      return;
    }
    _channel = channel;
    _retry = const Duration(seconds: 5);
    channel.stream.listen(
      (raw) {
        if (raw is String) _onMessage(raw);
      },
      onDone: _onClosed,
      onError: (_) => _onClosed(),
      cancelOnError: true,
    );
  }

  void _onClosed() {
    _channel = null;
    _haConnected = false;
    available.value = false;
    phase.value = SatellitePhase.idle;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    Timer(_retry, _connect);
    // Back off to once a minute while LVA stays down — a refused localhost
    // connect costs nothing, but there's no point hammering it.
    final next = _retry * 2;
    _retry = next > const Duration(minutes: 1) ? const Duration(minutes: 1) : next;
  }

  void _onMessage(String raw) {
    final Map<String, dynamic> msg;
    try {
      msg = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    final data = (msg['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    switch (msg['event']) {
      case 'snapshot':
        _haConnected = data['ha_connected'] == true;
        muted.value = data['muted'] == true;
      case 'disconnected':
        _haConnected = false;
        phase.value = SatellitePhase.idle;
      case 'zeroconf':
        if (data['status'] == 'connected') _haConnected = true;
      case 'muted':
        muted.value = data['muted'] == true;
      case 'wake_word_detected':
        _haConnected = true;
        phase.value = SatellitePhase.listening;
        _events.add(const SatelliteWake());
      case 'listening':
        phase.value = SatellitePhase.listening;
      case 'stt_text':
        final text = (data['text'] as String?)?.trim() ?? '';
        if (text.isNotEmpty) _events.add(SatelliteHeard(text));
      case 'thinking':
        phase.value = SatellitePhase.thinking;
      case 'tts_text':
        final text = (data['text'] as String?)?.trim() ?? '';
        if (text.isNotEmpty) _events.add(SatelliteReply(text));
      case 'tts_speaking':
        phase.value = SatellitePhase.speaking;
      case 'tts_finished' || 'idle':
        phase.value = SatellitePhase.idle;
      case 'pipeline_error':
        phase.value = SatellitePhase.idle;
        _events.add(SatelliteError('${data['reason'] ?? ''}'));
    }
    available.value = _haConnected;
  }

  void _send(String command) {
    _channel?.sink.add(jsonEncode({'command': command}));
  }

  /// Same as saying the wake word.
  void startListening() => _send('start_listening');

  /// Aborts the pipeline at whatever phase it's in.
  void stop() => _send('stop_pipeline');

  /// Stops/starts listening for the wake word (LVA's mic mute).
  void setMuted(bool mute) {
    _send(mute ? 'mute_mic' : 'unmute_mic');
    muted.value = mute;
  }
}
