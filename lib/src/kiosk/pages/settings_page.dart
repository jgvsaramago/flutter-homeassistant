import 'dart:async';
import 'dart:io' show NetworkInterface, InternetAddressType, exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../build_info.dart';
import '../../ha_client/ha_websocket_client.dart';
import '../../music/ma_client.dart';
import '../../music/music_store.dart';
import '../../providers/ha_providers.dart';
import '../../services/screen_brightness_service.dart';
import '../../services/screen_power_controller.dart';
import '../../services/system_control_service.dart';
import '../../services/voice_satellite.dart';
import '../modals/intercom_modal.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';
import '../widgets/music_widgets.dart';

final _haLanguageProvider = FutureProvider<String?>((ref) async {
  await haReady(ref);
  final config = await ref.read(haWebSocketClientProvider).getConfig();
  return config['language'] as String?;
});

final _networkProvider = FutureProvider<String?>((ref) async {
  if (kIsWeb) return null;
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  final iface = interfaces.where((i) => i.name.startsWith('eth') || i.name.startsWith('end')).firstOrNull ?? interfaces.firstOrNull;
  if (iface == null || iface.addresses.isEmpty) return null;
  final kind = iface.name.startsWith('wl') ? 'Wi-Fi' : 'Ethernet';
  return '$kind · ${iface.addresses.first.address}';
});

/// Definições (design "Definições"): what belongs to this screen itself.
/// Opened by tapping the header's clock; everything that maps the screen
/// onto HA entities lives in HA's "Flutter Dashboard" panel instead.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KFadeUp(
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Definições', style: KText.d(46, spacing: -0.5)),
                  const Spacer(),
                  Text('Toque no relógio, em qualquer página, para voltar aqui.', style: KText.s(20, color: KColors.muted)),
                ],
              ),
              const SizedBox(height: 28),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ScreenGroup()),
                  SizedBox(width: 28),
                  Expanded(child: _VoiceGroup()),
                ],
              ),
              const SizedBox(height: 28),
              const _ConnectionsGroup(),
              const SizedBox(height: 28),
              const _SystemGroup(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.icon, required this.title, required this.rows});

  final String icon;
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: KMusic.paper, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: KIcon(icon, size: 28, color: KColors.accent, stroke: 1.9),
                ),
                const SizedBox(width: 16),
                Text(title, style: KText.d(34)),
              ],
            ),
          ),
          for (final (i, r) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: Color(0xFFE9E5DD), width: 1.5))),
              child: r,
            ),
        ],
      ),
    );
  }
}

/// Label (+ optional sub) on the left, [trailing] on the right.
class _Row extends StatelessWidget {
  const _Row({required this.label, this.sub, this.trailing, this.dot, this.below});

  final String label;
  final String? sub;
  final Widget? trailing;
  final Color? dot;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              if (dot != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: dot!.withValues(alpha: .16), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Container(width: 14, height: 14, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 20),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: KText.s(22, weight: FontWeight.w600)),
                    if (sub != null && sub!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(sub!, style: KText.s(17, color: KColors.muted, height: 1.4)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 20), trailing!],
            ],
          ),
        ),
        if (below != null) ...[const SizedBox(height: 14), below!],
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.sub, required this.state});

  final String label;
  final String sub;

  /// `ok`, `wait`, `off`.
  final String state;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (state) {
      'ok' => (KColors.green, 'Ligado'),
      'wait' => (KColors.amber, 'A ligar'),
      _ => (KColors.orange, 'Sem ligação'),
    };
    return _Row(
      label: label,
      sub: sub,
      dot: color,
      trailing: Text(text, style: KText.s(22, weight: FontWeight.w600, color: state == 'wait' ? KColors.amberInk : color)),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => KPress(
    onTap: onTap,
    child: Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: KMusic.line, width: 1.5)),
      child: Text(label, style: KText.s(20, weight: FontWeight.w600)),
    ),
  );
}

// ------------------------------------------------------------------------ Ecrã

class _ScreenGroup extends StatefulWidget {
  const _ScreenGroup();

  @override
  State<_ScreenGroup> createState() => _ScreenGroupState();
}

class _ScreenGroupState extends State<_ScreenGroup> {
  static const _service = ScreenBrightnessService();
  double? _percent;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (_service.isSupported) {
      _service.readPercent().then((v) {
        if (mounted) setState(() => _percent = (v ?? 100).toDouble());
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(double v) {
    setState(() => _percent = v);
    // Each DDC/CI write takes ~100 ms on the monitor's I²C bus; only send
    // once the slider settles (the service also collapses bursts).
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      if (!await _service.setPercent(v.round())) KToast.show('Não foi possível alterar o brilho', error: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _percent;
    return _Group(
      icon: KIcons.screen,
      title: 'Ecrã',
      rows: [
        _Row(
          label: 'Brilho',
          sub: _service.isSupported ? 'O brilho do monitor, por DDC/CI.' : 'Indisponível neste ecrã.',
          below: Row(
            children: [
              const KIcon(KIcons.sun, size: 26, color: KColors.muted, stroke: 2),
              const SizedBox(width: 18),
              Expanded(
                child: KSlider(
                  value: (p ?? 0) / 100,
                  enabled: p != null,
                  height: 52,
                  trackHeight: 12,
                  knob: 36,
                  track: KMusic.line,
                  fill: KColors.accent,
                  onChanged: (v) => _changed((v * 100).roundToDouble()),
                ),
              ),
              SizedBox(width: 72, child: Text(p == null ? '--' : '${p.round()}%', textAlign: TextAlign.right, style: KText.s(22, weight: FontWeight.w600))),
            ],
          ),
        ),
        _Row(
          label: 'Desligar o ecrã',
          sub: 'Apaga já. Volta a acender ao tocar.',
          trailing: _OutlineButton(label: 'Desligar', onTap: () => ScreenPowerController.instance.setPowered(false)),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Assistente de voz

class _VoiceGroup extends ConsumerWidget {
  const _VoiceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(_haLanguageProvider).valueOrNull;
    final sat = VoiceSatellite.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([sat.available, sat.muted]),
      builder: (context, _) {
        final available = sat.available.value;
        final on = available && !sat.muted.value;
        return _Group(
          icon: KIcons.micStand,
          title: 'Assistente de voz',
          rows: [
            _Row(
              label: 'Palavra de ativação',
              sub: available ? 'Diga "Ok Nabu" para falar com o assistente.' : 'O microfone ainda não está ligado a este ecrã.',
              trailing: Opacity(
                opacity: available ? 1 : 0.45,
                child: KPress(onTap: available ? () => sat.setMuted(on) : null, child: KSwitch(on: on)),
              ),
            ),
            _Row(
              label: 'Idioma',
              sub: 'Definido no Home Assistant.',
              trailing: Text(_languageName(language), style: KText.s(22, weight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  static String _languageName(String? code) => switch (code) {
    null => '--',
    'pt' || 'pt-PT' => 'Português (Portugal)',
    'pt-BR' => 'Português (Brasil)',
    'en' || 'en-GB' || 'en-US' => 'English',
    'es' => 'Español',
    'fr' => 'Français',
    _ => code,
  };
}

// --------------------------------------------------------------------- Ligações

class _ConnectionsGroup extends ConsumerWidget {
  const _ConnectionsGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ha = ref.watch(haConnectionStateProvider).valueOrNull ?? HaConnectionState.disconnected;
    final url = ref.watch(connectionConfigProvider)?.baseUrl ?? '--';
    final host = Uri.tryParse(url)?.host ?? url;
    final count = ref.watch(entitiesProvider.select((a) => a.valueOrNull?.length ?? 0));
    final music = ref.watch(musicStoreProvider.select((m) => (conn: m.connection, speakers: m.speakers.where((p) => p.available).length)));
    final net = ref.watch(_networkProvider).valueOrNull;
    final haState = switch (ha) {
      HaConnectionState.connected => 'ok',
      HaConnectionState.connecting || HaConnectionState.authenticating => 'wait',
      _ => 'off',
    };
    final maState = switch (music.conn) {
      MaConnectionState.connected => 'ok',
      MaConnectionState.connecting => 'wait',
      _ => 'off',
    };
    return _Group(
      icon: KIcons.wifi,
      title: 'Ligações',
      rows: [
        _Status(label: 'Home Assistant', sub: '$host · $count entidades', state: haState),
        _Status(
          label: 'Music Assistant',
          sub: music.conn == MaConnectionState.connected
              ? '${music.speakers} colunas encontradas'
              : (music.conn == MaConnectionState.unavailable ? 'Add-on não encontrado no Home Assistant' : 'Através do Home Assistant'),
          state: maState,
        ),
        const _IntercomStatus(),
        if (net != null) _Status(label: 'Rede', sub: net, state: 'ok'),
      ],
    );
  }
}

/// The intercom's row: healthy while a ring would reach this screen — the
/// same signal as the shell's loud doorbell banner.
class _IntercomStatus extends ConsumerWidget {
  const _IntercomStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intercom = ref.watch(intercomControllerProvider);
    if (!intercom.connected) return const _Status(label: 'Intercomunicador', sub: 'Hikvision · não configurado neste ecrã', state: 'off');
    final problem = intercom.doorbellProblem;
    if (problem == null) return const _Status(label: 'Intercomunicador', sub: 'Hikvision · câmara da porta', state: 'ok');
    return ValueListenableBuilder<String?>(
      valueListenable: problem,
      builder: (context, why, _) => _Status(label: 'Intercomunicador', sub: why ?? 'Hikvision · campainha e câmara da porta', state: why == null ? 'ok' : 'off'),
    );
  }
}

// ---------------------------------------------------------------------- Sistema

class _SystemGroup extends StatelessWidget {
  const _SystemGroup();

  Future<void> _confirm(BuildContext context, {required String title, required String text, required String cta, required String toast, required Future<void> Function() action}) async {
    final ok = await showKModal<bool>(
      context,
      (ctx) => KModal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: KText.modalTitle),
            const SizedBox(height: 20),
            Text(text, style: KText.s(22, color: KColors.muted, height: 1.45)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KButton(label: 'Cancelar', height: 72, padding: const EdgeInsets.symmetric(horizontal: 40), onTap: () => Navigator.of(ctx).pop(false)),
                const SizedBox(width: 14),
                KButton.primary(label: cta, height: 72, padding: const EdgeInsets.symmetric(horizontal: 44), onTap: () => Navigator.of(ctx).pop(true)),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    KToast.show(toast);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final system = SystemControlService();
    return _Group(
      icon: KIcons.gear,
      title: 'Sistema',
      rows: [
        _Row(
          label: 'Versão',
          sub: 'Atualizada pelo deploy no Raspberry Pi.',
          trailing: Text('$kBuildRevision · flutter-pi', style: KText.s(22, weight: FontWeight.w600)),
        ),
        const _Row(
          label: 'Configurar entidades',
          sub: 'Pessoas, divisões, energia e carros configuram-se no painel "Flutter Dashboard" do Home Assistant.',
        ),
        if (!kIsWeb)
          _Row(
            label: 'Reiniciar a app',
            sub: 'Recarrega o ecrã. Demora uns segundos.',
            trailing: _OutlineButton(
              label: 'Reiniciar a app',
              onTap: () => _confirm(
                context,
                title: 'Reiniciar a app?',
                text: 'O ecrã fica em branco durante uns segundos e volta à página Início.',
                cta: 'Reiniciar',
                toast: 'A reiniciar a app…',
                // The systemd service restarts the app whenever it exits.
                action: () async => exit(0),
              ),
            ),
          ),
        if (system.isSupported)
          _Row(
            label: 'Reiniciar o ecrã',
            sub: 'Reinicia o Raspberry Pi. Demora cerca de 1 minuto.',
            trailing: _OutlineButton(
              label: 'Reiniciar o ecrã',
              onTap: () => _confirm(
                context,
                title: 'Reiniciar o ecrã?',
                text: 'O Raspberry Pi reinicia. O ecrã fica indisponível durante cerca de 1 minuto.',
                cta: 'Reiniciar o ecrã',
                toast: 'A reiniciar o ecrã…',
                action: () async {
                  if (!await system.reboot()) KToast.show('Não foi possível reiniciar', error: true);
                },
              ),
            ),
          ),
      ],
    );
  }
}
