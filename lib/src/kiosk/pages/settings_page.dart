import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ha_client/ha_websocket_client.dart';
import '../../mqtt/mqtt_connection_status.dart';
import '../../providers/ha_providers.dart';
import '../../services/screen_brightness_service.dart';
import '../../services/system_control_service.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

/// Definições: only what belongs to this screen itself — connection
/// status, brightness, restart. Everything that maps the app onto HA
/// entities is edited in HA's sidebar panel ("Flutter Dashboard").
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ha = ref.watch(haConnectionStateProvider).valueOrNull ?? HaConnectionState.disconnected;
    final url = ref.watch(connectionConfigProvider)?.baseUrl ?? '--';
    final count = ref.watch(entitiesProvider.select((a) => a.valueOrNull?.length ?? 0));
    final (haLabel, haColor) = switch (ha) {
      HaConnectionState.connected => ('Ligado', KColors.green),
      HaConnectionState.connecting || HaConnectionState.authenticating => ('A ligar', KColors.amber),
      HaConnectionState.error => ('Erro', KColors.red),
      HaConnectionState.disconnected => ('Desligado', KColors.faint),
    };
    return KFadeUp(
      child: KSection(
        padding: const EdgeInsets.all(28),
        child: ListView(
          children: [
            Text('Definições', style: KText.pageTitle),
            const SizedBox(height: 4),
            Text(
              'Deste ecrã',
              style: KText.s(20, weight: FontWeight.w500, color: KColors.muted),
            ),
            const SizedBox(height: 24),
            _Panel(
              title: 'Ligações',
              child: Column(
                children: [
                  _StatusRow(label: 'Home Assistant', value: haLabel, dot: haColor),
                  _StatusRow(label: 'Endereço', value: url),
                  _StatusRow(label: 'Entidades', value: '$count'),
                  ValueListenableBuilder<MqttConnectionStatus>(
                    valueListenable: MqttConnectionController.instance.status,
                    builder: (context, s, _) {
                      final (label, color) = switch (s) {
                        MqttConnectionStatus.connected => ('Ligado', KColors.green),
                        MqttConnectionStatus.connecting => ('A ligar', KColors.amber),
                        MqttConnectionStatus.error => ('Erro', KColors.red),
                        MqttConnectionStatus.disconnected => ('Desligado', KColors.faint),
                        MqttConnectionStatus.disabled => ('Não configurado', KColors.faint),
                      };
                      return _StatusRow(label: 'MQTT', value: label, dot: color, last: true);
                    },
                  ),
                ],
              ),
            ),
            if (const ScreenBrightnessService().isSupported) ...[const SizedBox(height: 16), const _BrightnessPanel()],
            if (SystemControlService().isSupported) ...[const SizedBox(height: 16), const _RestartPanel()],
            const SizedBox(height: 28),
            Text(
              'Divisões, energia, calendários, carros, família e o resto do ecrã configuram-se no Home Assistant, '
              'em Flutter Dashboard na barra lateral.',
              style: KText.s(20, color: KColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: KText.s(26, weight: FontWeight.w600)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value, this.dot, this.last = false});

  final String label;
  final String value;
  final Color? dot;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: KColors.divider, width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: KText.s(22, color: KColors.ink2)),
          ),
          if (dot != null) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
          ],
          Text(value, style: KText.s(22, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BrightnessPanel extends StatefulWidget {
  const _BrightnessPanel();

  @override
  State<_BrightnessPanel> createState() => _BrightnessPanelState();
}

class _BrightnessPanelState extends State<_BrightnessPanel> {
  static const _service = ScreenBrightnessService();
  double? _percent;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _service.readPercent().then((v) {
      if (mounted) setState(() => _percent = (v ?? 100).toDouble());
    });
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
    return _Panel(
      title: 'Brilho do ecrã',
      child: Row(
        children: [
          const KIcon(KIcons.sun, size: 32, color: KColors.muted, stroke: 1.8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 12,
                activeTrackColor: KColors.accent,
                inactiveTrackColor: KColors.border,
                thumbColor: Colors.white,
                overlayColor: KColors.accent.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 22, elevation: 3),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 40),
              ),
              child: Slider(value: (p ?? 0).clamp(0, 100), max: 100, onChanged: p == null ? null : _changed),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(p == null ? '--' : '${p.round()}%', textAlign: TextAlign.right, style: KText.d(32)),
          ),
        ],
      ),
    );
  }
}

class _RestartPanel extends StatefulWidget {
  const _RestartPanel();

  @override
  State<_RestartPanel> createState() => _RestartPanelState();
}

class _RestartPanelState extends State<_RestartPanel> {
  bool _restarting = false;

  Future<void> _restart() async {
    final ok = await showKModal<bool>(context, (_) => const _ConfirmRestart());
    if (ok != true || !mounted) return;
    setState(() => _restarting = true);
    final done = await SystemControlService().reboot();
    // A successful reboot ends this process within seconds; still being
    // here means it failed.
    if (!mounted) return;
    setState(() => _restarting = done);
    if (!done) KToast.show('Não foi possível reiniciar', error: true);
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Reiniciar o ecrã',
      child: Row(
        children: [
          Expanded(
            child: Text('O ecrã fica indisponível durante cerca de um minuto.', style: KText.s(20, color: KColors.muted)),
          ),
          const SizedBox(width: 16),
          KButton(label: _restarting ? 'A reiniciar…' : 'Reiniciar', icon: KIcons.refresh, height: 64, onTap: _restarting ? null : _restart),
        ],
      ),
    );
  }
}

class _ConfirmRestart extends StatelessWidget {
  const _ConfirmRestart();

  @override
  Widget build(BuildContext context) {
    return KModal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KModalHeader(title: 'Reiniciar o ecrã?'),
          const SizedBox(height: 16),
          Text('O Raspberry Pi reinicia e o ecrã volta dentro de cerca de um minuto.', style: KText.s(22, color: KColors.muted)),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              KButton(label: 'Cancelar', height: 72, padding: const EdgeInsets.symmetric(horizontal: 40), onTap: () => Navigator.of(context).pop(false)),
              const SizedBox(width: 14),
              KButton.primary(
                label: 'Reiniciar',
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 44),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
