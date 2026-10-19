import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/voice_satellite.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

/// Opens the Assistente. From the nav bar ([byVoice] false) it starts
/// listening straight away, as if the wake word had been said.
Future<void> showAssistant(BuildContext context, {bool byVoice = false}) async {
  if (AssistantModal.isOpen) return;
  AssistantModal.isOpen = true;
  try {
    await showKModal(context, (_) => AssistantModal(byVoice: byVoice));
  } finally {
    AssistantModal.isOpen = false;
  }
}

class _Msg {
  const _Msg.user(this.text) : user = true;
  const _Msg.bot(this.text) : user = false;

  final bool user;
  final String text;
}

/// The design's "Assistente": a spoken conversation with Home Assistant's
/// Assist, voice only. The mic, wake word, speech-to-text and speaker all
/// belong to Linux Voice Assistant on this Pi ([VoiceSatellite]); this shows
/// what it heard and answered, follows its listening/thinking/speaking
/// state, and its mic button starts/stops a pipeline.
class AssistantModal extends StatefulWidget {
  const AssistantModal({super.key, this.byVoice = false});

  /// Opened by the wake word — LVA is already listening.
  final bool byVoice;

  static bool isOpen = false;

  @override
  State<AssistantModal> createState() => _AssistantModalState();
}

class _AssistantModalState extends State<AssistantModal> {
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  StreamSubscription<SatelliteEvent>? _voice;

  static final _satellite = VoiceSatellite.instance;

  @override
  void initState() {
    super.initState();
    _voice = _satellite.events.listen(_onVoice);
    if (!widget.byVoice && _satellite.available.value && _satellite.phase.value == SatellitePhase.idle) {
      _satellite.startListening();
    }
  }

  @override
  void dispose() {
    _voice?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onVoice(SatelliteEvent e) {
    final msg = switch (e) {
      SatelliteHeard(:final text) => _Msg.user(text),
      SatelliteReply(:final text) => _Msg.bot(text),
      SatelliteError() => const _Msg.bot('Desculpe, não percebi. Pode repetir?'),
      SatelliteWake() => null,
    };
    if (msg == null) return;
    setState(() => _messages.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: kEase);
    });
  }

  void _toggleMic() {
    if (_satellite.phase.value == SatellitePhase.idle) {
      _satellite.startListening();
    } else {
      _satellite.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_satellite.available, _satellite.phase]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final voice = _satellite.available.value;
    final phase = _satellite.phase.value;
    final listening = phase == SatellitePhase.listening;
    final (status, statusBg, statusFg, blink) = switch (phase) {
      SatellitePhase.listening => ('A ouvir…', KColors.accentSoft, KColors.accent, const Duration(milliseconds: 1200)),
      SatellitePhase.thinking => ('A pensar…', KColors.amberTint, KColors.amberInk, const Duration(milliseconds: 800)),
      SatellitePhase.speaking => ('A responder…', KColors.greenTint, KColors.greenInk, const Duration(milliseconds: 1200)),
      SatellitePhase.idle => ('Pronto', KColors.chip, KColors.ink2, null),
    };
    final liveText = switch (phase) {
      _ when !voice => 'O assistente de voz não está disponível de momento',
      SatellitePhase.listening => 'A ouvir…',
      SatellitePhase.thinking || SatellitePhase.speaking => '',
      SatellitePhase.idle => 'Toque no microfone para continuar a conversa',
    };
    return KModal(
      padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: KColors.accentSoft, borderRadius: BorderRadius.circular(20)),
                child: const Center(child: KIcon(KIcons.wave, size: 32, color: KColors.accent, stroke: 2)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assistente', style: KText.modalTitle),
                    Text('Home Assistant · Assist', style: KText.s(18, color: KColors.muted)),
                  ],
                ),
              ),
              Container(
                height: 48,
                padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    KBlink(
                      enabled: blink != null,
                      period: blink ?? const Duration(milliseconds: 1200),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: statusFg, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: KText.s(18, weight: FontWeight.w700, color: statusFg),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              KCircleButton(
                icon: KIcons.close,
                size: 64,
                iconSize: 26,
                stroke: 2.2,
                bg: KColors.chip,
                border: null,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 1000),
            child: _messages.isEmpty && phase != SatellitePhase.thinking
                ? (listening
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Diga, por exemplo, “Acende as luzes da cozinha” ou “Qual é a temperatura da água?”',
                            style: KText.s(20, color: KColors.muted, height: 1.4),
                          ),
                        ))
                : ListView(
                    controller: _scroll,
                    shrinkWrap: true,
                    children: [
                      for (final m in _messages) Padding(padding: const EdgeInsets.only(bottom: 18), child: _bubble(m)),
                      if (phase == SatellitePhase.thinking) const Align(alignment: Alignment.centerLeft, child: _Typing()),
                    ],
                  ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.only(top: 24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: KColors.divider, width: 1.5)),
            ),
            child: Row(
              children: [
                _MicButton(
                  listening: listening,
                  enabled: voice,
                  onTap: voice ? _toggleMic : null,
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (listening) ...[const _VoiceWave(), const SizedBox(height: 10)],
                      if (liveText.isNotEmpty)
                        Text(
                          liveText,
                          style: KText.s(22, color: listening ? KColors.ink : KColors.muted, height: 1.3).copyWith(
                            fontStyle: listening ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) {
    if (m.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(
              color: KColors.accent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text(m.text, style: KText.s(22, color: Colors.white, height: 1.35)),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: const BoxDecoration(
            color: KColors.chip,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Text(m.text, style: KText.s(22, height: 1.35)),
        ),
      ),
    );
  }
}

/// 96 px mic; while listening it's filled with the accent and a ring
/// pulses out of it (the design's `dcMic`: 34 px, 1.6 s, ease-out, done
/// by 75%).
class _MicButton extends StatefulWidget {
  const _MicButton({required this.listening, required this.enabled, this.onTap});

  final bool listening;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.listening) _c.repeat();
  }

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    if (widget.listening == old.listening) return;
    if (widget.listening) {
      _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.listening;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final k = Curves.easeOut.transform((v / 0.75).clamp(0.0, 1.0));
        return Opacity(
          opacity: widget.enabled ? 1 : 0.45,
          child: KCircleButton(
            icon: KIcons.mic,
            size: 96,
            iconSize: 40,
            stroke: 2,
            bg: on ? KColors.accent : KColors.chip,
            fg: on ? Colors.white : KColors.ink,
            border: null,
            shadow: on && v < 0.75 ? [BoxShadow(color: KColors.accent.withValues(alpha: 0.45 * (1 - k)), spreadRadius: 34 * k)] : null,
            onTap: widget.onTap,
          ),
        );
      },
    );
  }
}

/// Nine 8×56 bars bouncing between 25% and full height at staggered
/// speeds — the design's `dcWave`.
class _VoiceWave extends StatefulWidget {
  const _VoiceWave();

  @override
  State<_VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<_VoiceWave> with SingleTickerProviderStateMixin {
  static const _periods = [0.70, 0.83, 0.96, 1.09];
  static const _loop = 60.0;
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * _loop;
          return Row(
            children: [
              for (var i = 0; i < 9; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Transform.scale(
                  scaleX: 1,
                  scaleY: _scale(t, i),
                  child: Container(
                    width: 8,
                    height: 56,
                    decoration: BoxDecoration(color: KColors.accent, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static double _scale(double t, int i) {
    final p = ((t - i * 0.09) / _periods[i % 4]) % 1;
    return 0.25 + 0.75 * (1 - math.cos(2 * math.pi * p)) / 2;
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      decoration: const BoxDecoration(
        color: KColors.chip,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            KBlink(
              period: Duration(milliseconds: 1000 + i * 150),
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(color: KColors.faint, shape: BoxShape.circle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
