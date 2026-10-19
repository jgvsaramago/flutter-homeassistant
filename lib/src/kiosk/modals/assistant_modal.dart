import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import '../../widgets/on_screen_keyboard_controller.dart';
import '../data/kiosk_entities.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

Future<void> showAssistant(BuildContext context) => showKModal(context, (_) => const AssistantModal());

/// The conversation agent of HA's preferred Assist pipeline — the same one
/// a voice satellite in the house would talk to.
final _assistAgentProvider = FutureProvider<String?>((ref) async {
  await ref.watch(entitiesProvider.future);
  try {
    final p = await ref.read(haWebSocketClientProvider).getAssistPipelines();
    final preferred = p['preferred_pipeline'];
    for (final pipe in (p['pipelines'] as List? ?? const []).whereType<Map>()) {
      if (pipe['id'] == preferred) return pipe['conversation_engine'] as String?;
    }
  } catch (_) {}
  return null;
});

class _Msg {
  const _Msg.user(this.text) : user = true, entityIds = const [];
  const _Msg.bot(this.text, this.entityIds) : user = false;

  final bool user;
  final String text;
  final List<String> entityIds;
}

/// The design's "Assistente": a conversation with Home Assistant's Assist.
/// This panel has no microphone, so requests are typed on the on-screen
/// keyboard; replies come back as text plus a card for each entity the
/// assistant changed.
class AssistantModal extends ConsumerStatefulWidget {
  const AssistantModal({super.key});

  @override
  ConsumerState<AssistantModal> createState() => _AssistantModalState();
}

class _AssistantModalState extends ConsumerState<AssistantModal> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  bool _thinking = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _messages.add(_Msg.user(text));
      _thinking = true;
    });
    _scrollDown();
    try {
      final agent = await ref.read(_assistAgentProvider.future);
      final r = await ref.read(haWebSocketClientProvider).conversationProcess(text: text, agentId: agent, conversationId: _conversationId);
      _conversationId = r['conversation_id'] as String? ?? _conversationId;
      final response = (r['response'] as Map?)?.cast<String, dynamic>() ?? const {};
      final speech = (((response['speech'] as Map?)?['plain'] as Map?)?['speech'] as String?)?.trim();
      final success = ((response['data'] as Map?)?['success'] as List?) ?? const [];
      final ids = [
        for (final t in success.whereType<Map>())
          if (t['type'] == 'entity' && t['id'] is String) t['id'] as String,
      ];
      if (mounted) setState(() => _messages.add(_Msg.bot(speech == null || speech.isEmpty ? 'Feito.' : speech, ids)));
    } catch (e) {
      if (mounted) setState(() => _messages.add(const _Msg.bot('Não consegui falar com o assistente. Tente de novo.', [])));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: kEase);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entities = ref.watch(kioskEntitiesProvider);
    final allEntities = ref.watch(entitiesProvider).valueOrNull ?? const <String, HaEntity>{};
    final (status, statusBg, statusFg) = _thinking ? ('A pensar…', KColors.amberTint, KColors.amberInk) : ('Pronto', KColors.chip, KColors.ink2);
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
                child: const Center(child: KIcon(KIcons.wave, size: 34, color: KColors.accent, stroke: 2)),
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
                      enabled: _thinking,
                      period: const Duration(milliseconds: 800),
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
                iconSize: 30,
                stroke: 2.2,
                bg: KColors.chip,
                border: null,
                onTap: () {
                  OnScreenKeyboardController.instance.close();
                  Navigator.of(context).maybePop();
                },
              ),
            ],
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 1000),
            child: _messages.isEmpty && !_thinking
                ? Text(
                    'Escreva, por exemplo, “Acende as luzes da cozinha” ou “Qual é a temperatura da água?”',
                    style: KText.s(20, color: KColors.muted, height: 1.4),
                  )
                : ListView(
                    controller: _scroll,
                    shrinkWrap: true,
                    children: [
                      for (final m in _messages) Padding(padding: const EdgeInsets.only(bottom: 18), child: _bubble(m, {...allEntities, ...entities})),
                      if (_thinking) const Align(alignment: Alignment.centerLeft, child: _Typing()),
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
                KCircleButton(
                  icon: KIcons.keyboard,
                  size: 96,
                  iconSize: 40,
                  stroke: 2,
                  bg: _focus.hasFocus ? KColors.accent : KColors.chip,
                  fg: _focus.hasFocus ? Colors.white : KColors.ink,
                  border: null,
                  onTap: () => _focus.hasFocus ? OnScreenKeyboardController.instance.close() : _focus.requestFocus(),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: KTextField(
                    controller: _input,
                    focusNode: _focus,
                    hint: 'Escreva um pedido…',
                    height: 84,
                    fontSize: 24,
                    autofocus: true,
                    options: KeyboardOptions(doneLabel: 'Enviar', onDone: _send),
                    trailing: KCircleButton(
                      icon: KIcons.send,
                      size: 60,
                      iconSize: 28,
                      stroke: 2.2,
                      bg: KColors.accent,
                      fg: Colors.white,
                      border: null,
                      onTap: _send,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m, Map<String, HaEntity> entities) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
            for (final id in m.entityIds.take(4))
              if (entities[id] case final e?) Padding(padding: const EdgeInsets.only(top: 12), child: _resultCard(e)),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(HaEntity e) {
    final (icon, bg, fg) = switch (e.domain) {
      'light' || 'switch' => (KIcons.bulb, KColors.amberTint, KColors.amberInk),
      'climate' => (KIcons.flame, KColors.orangeTint, KColors.orange),
      'water_heater' => (KIcons.boiler, KColors.orangeTint, KColors.orangeInk),
      'cover' => (KIcons.house, KColors.blueTint, KColors.blue),
      'lock' => (KIcons.lock, KColors.greenTint, KColors.greenInk),
      _ => (KIcons.check, KColors.chip, KColors.ink2),
    };
    final state = switch (e.domain) {
      'light' || 'switch' => e.isOn ? 'Ligada${numAttr(e, 'brightness') == null ? '' : ' a ${(numAttr(e, 'brightness')! / 255 * 100).round()}%'}' : 'Desligada',
      'climate' => e.state == 'off' ? 'Desligado' : 'Ligado · ${ptDeg(numAttr(e, 'current_temperature'))} → ${ptDeg(numAttr(e, 'temperature'))}',
      'lock' => e.state == 'locked' ? 'Trancada' : 'Destrancada',
      'cover' => e.state == 'closed' ? 'Fechado' : 'Aberto',
      _ => e.displayState,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Center(child: KIcon(icon, size: 26, color: fg)),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.friendlyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.s(20, weight: FontWeight.w600),
                ),
                Text(state, style: KText.s(17, color: KColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
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
