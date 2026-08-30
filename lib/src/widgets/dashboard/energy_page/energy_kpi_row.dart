import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/energy_forecast_provider.dart';
import '../../../providers/energy_history_provider.dart';
import '../../../providers/energy_page_settings_provider.dart';
import '../../../providers/energy_savings_provider.dart';
import '../../../theme/nocturne_theme.dart';
import '../../../utils/pt_format.dart';

/// Section 2 of the Energia page: Produzido / Consumo / Injetado / Poupança
/// — every value derived from today's real HA history (see
/// `EnergyHistoryData`), never typed in, so they can't disagree with the
/// hourly charts below that share the same source.
class EnergyKpiRow extends ConsumerWidget {
  const EnergyKpiRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(energyHistoryProvider).value ?? EnergyHistoryData.empty;
    final forecast = ref.watch(energyForecastProvider);
    final pageConfig = ref.watch(energyPageConfigProvider);

    final produced = history.hasSolar ? history.producedTodayKwh : null;
    final consumed = history.hasHome ? history.consumedTodayKwh : null;
    final gridImport = history.hasHome ? history.gridImportTodayKwh : null;
    final injected = history.hasSolar ? history.injectedTodayKwh : null;
    final expectedToday = forecast.todayTotalKwh;

    final importPrice = pageConfig.importPricePerKwh;
    final exportPrice = pageConfig.exportPricePerKwh;
    final selfConsumed = produced == null ? null : produced - (injected ?? 0);
    final receivable = (injected != null && exportPrice != null) ? injected * exportPrice : null;
    final savingsToday = (selfConsumed != null && importPrice != null) ? selfConsumed * importPrice + (receivable ?? 0) : null;

    AsyncValue<double>? monthSavings;
    if (savingsToday != null) monthSavings = ref.watch(energyMonthSavingsProvider(savingsToday));

    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            label: 'Produzido',
            value: formatKwh(produced) ?? '--',
            sub: expectedToday == null ? '--' : 'previsto ${formatKwh(expectedToday)}',
            color: NocturneColors.solarMark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(
            label: 'Consumo',
            value: formatKwh(consumed) ?? '--',
            sub: gridImport == null ? '--' : '${formatKwh(gridImport)} da rede',
            color: NocturneColors.text,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(
            label: 'Injetado',
            value: formatKwh(injected) ?? '--',
            sub: receivable == null ? '--' : '${formatEuro(receivable)} a receber',
            color: NocturneColors.gridMark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiTile(
            label: 'Poupança',
            value: formatEuro(savingsToday) ?? '--',
            sub: monthSavings?.value == null ? '--' : '${formatEuro(monthSavings!.value)} este mês',
            color: NocturneColors.batteryMark,
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.sub, required this.color});

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, letterSpacing: 1.1, color: NocturneColors.neutral500),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600, height: 1, color: color)),
          const SizedBox(height: 6),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: NocturneColors.neutral500)),
        ],
      ),
    );
  }
}
