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
              Text('Energia', style: NocturneText.pageTitle),
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(fontSize: 18, color: NocturneColors.neutral400)),
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: NocturneColors.batteryMark),
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

/// A `SingleTickerProviderStateMixin` + `AnimationController(..repeat())`
/// here ticks every frame at the display's full refresh rate for as long as
/// this dot is mounted — i.e. the whole time the Energia page is open — for
/// a 9px dot that only needs to look like it's gently pulsing. That's the
/// exact CPU anti-pattern `EnergyFlowCard`'s own mesh ticker already went
/// through once (see its `_tickInterval` doc comment): a throttled `Timer`
/// computing an eased value from elapsed time costs a fraction as much as a
/// vsync-driven controller for ambient motion like this.
class _BlinkDotState extends State<_BlinkDot> {
  static const _period = Duration(milliseconds: 1200);
  static const _tickInterval = Duration(milliseconds: 100);

  final _stopwatch = Stopwatch()..start();
  Timer? _timer;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _updateOpacity();
    _timer = Timer.periodic(_tickInterval, (_) => setState(_updateOpacity));
  }

  void _updateOpacity() {
    final t = (_stopwatch.elapsedMilliseconds % _period.inMilliseconds) / _period.inMilliseconds;
    // Triangle wave 0->1->0 across one period, eased the same as the
    // original CurvedAnimation, then mapped onto the same [0.2, 1.0] range.
    final triangle = t < 0.5 ? t * 2 : (1 - t) * 2;
    _opacity = 0.2 + 0.8 * Curves.easeInOut.transform(triangle);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: NocturneColors.batteryMark),
        child: SizedBox(width: 9, height: 9),
      ),
    );
  }
}
