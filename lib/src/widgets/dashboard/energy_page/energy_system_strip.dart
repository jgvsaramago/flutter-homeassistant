import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ha_entity.dart';
import '../../../providers/energy_history_provider.dart';
import '../../../providers/energy_page_settings_provider.dart';
import '../../../providers/ha_providers.dart';
import '../../../theme/nocturne_theme.dart';
import '../../../utils/pt_format.dart';

const _monthAbbrevPt = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
const _okStates = {'on', 'ok', 'normal', 'online', 'running', 'active'};

HaEntity? _entity(Map<String, HaEntity> entities, String? id) {
  if (id == null || id.trim().isEmpty) return null;
  final entity = entities[id];
  return (entity == null || entity.isUnavailable) ? null : entity;
}

/// Section 9 of the Energia page: installed capacity, inverter health,
/// today's yield-per-kWp, and manually-set panel-cleaning dates (no HA
/// entity tracks panel cleaning, so those two stay settings-page facts).
class EnergySystemStrip extends ConsumerWidget {
  const EnergySystemStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(energyPageConfigProvider);
    final history = ref.watch(energyHistoryProvider).value;
    final entities = ref.watch(entitiesProvider.select((async) => async.value ?? const {}));

    final installedKwp = config.installedKwp;
    final kwpMain = installedKwp == null ? '--' : '${ptNumber(installedKwp, decimals: 1)} kWp';
    final panelParts = [
      if (config.panelCount != null) '${config.panelCount} painéis',
      if ((config.panelOrientation ?? '').trim().isNotEmpty) config.panelOrientation!.trim(),
    ];
    final panelsSub = panelParts.isEmpty ? '--' : panelParts.join(' · ');

    final statusEntity = _entity(entities, config.inverterStatusEntityId);
    final inverterMain = statusEntity == null
        ? '--'
        : _okStates.contains(statusEntity.state.toLowerCase())
        ? 'OK'
        : statusEntity.displayState;

    final tempEntity = _entity(entities, config.inverterTemperatureEntityId);
    final effEntity = _entity(entities, config.inverterEfficiencyEntityId);
    final inverterSubParts = [
      if (tempEntity != null) '${_roundedOrRaw(tempEntity)} °C',
      if (effEntity != null) '${_roundedOrRaw(effEntity)}%',
    ];
    final inverterSub = inverterSubParts.isEmpty ? '--' : inverterSubParts.join(' · ');

    final producedToday = history?.hasSolar == true ? history!.producedTodayKwh : null;
    final yieldPerKwp = (producedToday != null && installedKwp != null && installedKwp > 0) ? producedToday / installedKwp : null;
    final yieldMain = yieldPerKwp == null ? '--' : '${ptNumber(yieldPerKwp, decimals: 2)} kWh/kWp';

    final nextCleaning = config.nextCleaningDate;
    final nextCleaningMain = nextCleaning == null ? '--' : '${nextCleaning.day} ${_monthAbbrevPt[nextCleaning.month - 1]}';
    final lastCleaning = config.lastCleaningDate;
    final lastCleaningSub = lastCleaning == null ? '--' : 'última há ${DateTime.now().difference(lastCleaning).inDays} dias';

    return Container(
      height: 132,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
      child: Row(
        children: [
          Expanded(child: _Cell(label: 'Potência instalada', main: kwpMain, sub: panelsSub, borderLeft: false)),
          Expanded(child: _Cell(label: 'Inversor', main: inverterMain, sub: inverterSub)),
          Expanded(child: _Cell(label: 'Rendimento', main: yieldMain, sub: 'hoje')),
          Expanded(child: _Cell(label: 'Próxima limpeza', main: nextCleaningMain, sub: lastCleaningSub)),
        ],
      ),
    );
  }

  String _roundedOrRaw(HaEntity entity) {
    final value = double.tryParse(entity.state);
    return value == null ? entity.state : ptNumber(value, decimals: 1);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.main, required this.sub, this.borderLeft = true});

  final String label;
  final String main;
  final String sub;
  final bool borderLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: borderLeft ? const BoxDecoration(border: Border(left: BorderSide(color: NocturneColors.neutral800))) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: NocturneColors.neutral500)),
          const SizedBox(height: 2),
          Text(main, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: NocturneColors.neutral500)),
        ],
      ),
    );
  }
}
