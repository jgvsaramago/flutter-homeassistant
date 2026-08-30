import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/energy_entities_provider.dart';
import '../../../providers/energy_history_provider.dart';
import '../../../providers/energy_page_settings_provider.dart';
import '../../../providers/ha_providers.dart';
import '../../../theme/nocturne_theme.dart';
import '../../../utils/power_reading.dart';
import '../../../utils/pt_format.dart';

/// Section 1 of the Energia page: title, live subtitle (installed kWp,
/// inverter status, clock, current home draw), and the "autoconsumo" pill.
class EnergyPageHeader extends ConsumerStatefulWidget {
  const EnergyPageHeader({super.key});

  @override
  ConsumerState<EnergyPageHeader> createState() => _EnergyPageHeaderState();
}

class _EnergyPageHeaderState extends ConsumerState<EnergyPageHeader> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageConfig = ref.watch(energyPageConfigProvider);
    final entityConfig = ref.watch(energyEntityConfigProvider);
    final readings = ref.watch(
      entitiesProvider.select((async) {
        final entities = async.value ?? const {};
        return (
          solarKw: readPowerKw(entities, entityConfig.solarPowerEntityId, entityConfig.solarZeroThresholdW),
          homeKw: readPowerKw(entities, entityConfig.homePowerEntityId, entityConfig.homeZeroThresholdW),
        );
      }),
    );
    final history = ref.watch(energyHistoryProvider).value;

    final time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final kwpText = pageConfig.installedKwp == null ? '--' : ptNumber(pageConfig.installedKwp!, decimals: 1);
    final inverterOn = (readings.solarKw ?? 0) > 0;
    final homeKwText = formatKw(readings.homeKw) ?? '--';
    final subtitle = 'Solar $kwpText kWp · inversor ${inverterOn ? 'ligado' : 'em standby'} · $time · $homeKwText';

    double? autoconsumoPercent;
    if (history != null && history.hasSolar) {
      final produced = history.producedTodayKwh;
      if (produced > 0.01) {
        autoconsumoPercent = ((produced - history.injectedTodayKwh) / produced * 100).clamp(0, 100);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Energia', style: NocturneText.pageTitle),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(fontSize: 18, color: NocturneColors.neutral400)),
            ],
          ),
        ),
        if (autoconsumoPercent != null) _AutoconsumoPill(percent: autoconsumoPercent),
      ],
    );
  }
}

class _AutoconsumoPill extends StatelessWidget {
  const _AutoconsumoPill({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NocturneRadii.pill),
        color: Color.alphaBlend(NocturneColors.batteryMark.withValues(alpha: 0.16), NocturneColors.surface),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BlinkDot(),
          const SizedBox(width: 8),
          Text(
            'Autoconsumo ${percent.round()}%',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: NocturneColors.batteryMark),
          ),
        ],
      ),
    );
  }
}

class _BlinkDot extends StatefulWidget {
  const _BlinkDot();

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeInOut).drive(Tween(begin: 1.0, end: 0.2)),
      child: const DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: NocturneColors.batteryMark),
        child: SizedBox(width: 9, height: 9),
      ),
    );
  }
}
