import 'package:flutter/material.dart';

import '../theme/nocturne_theme.dart';
import '../widgets/dashboard/energy_flow_card.dart';
import '../widgets/dashboard/energy_page/energy_consumption_chart.dart';
import '../widgets/dashboard/energy_page/energy_forecast_7d_section.dart';
import '../widgets/dashboard/energy_page/energy_kpi_row.dart';
import '../widgets/dashboard/energy_page/energy_page_header.dart';
import '../widgets/dashboard/energy_page/energy_plano_section.dart';
import '../widgets/dashboard/energy_page/energy_production_chart.dart';
import '../widgets/dashboard/energy_page/energy_system_strip.dart';
import '../widgets/shell/app_nav_bar.dart';

/// The "Energia" tab — unlike every other tab this one scrolls: real system
/// facts, today's KPIs, the compact flow card (reused as-is), two hourly
/// history charts, a 7-day solar forecast, and a system-health strip add up
/// to more height than the 1920px panel, so this is a `SingleChildScrollView`
/// rather than the fixed-grid `Column` the Homepage tab uses. Every direct
/// child gets its own fixed height (or sizes to its own content) — nothing
/// here is wrapped in `Expanded`, since there's no bounded height for it to
/// share.
class EnergyScreen extends StatelessWidget {
  const EnergyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        NocturneSpacing.pagePadding.left,
        NocturneSpacing.pagePadding.top,
        NocturneSpacing.pagePadding.right,
        AppNavBar.floatingClearance + MediaQuery.paddingOf(context).bottom + NocturneSpacing.rowGap,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EnergyPageHeader(),
          SizedBox(height: NocturneSpacing.rowGap),
          EnergyKpiRow(),
          SizedBox(height: NocturneSpacing.rowGap),
          EnergyPlanoSection(),
          SizedBox(height: NocturneSpacing.rowGap),
          SizedBox(height: 456, child: EnergyFlowCard()),
          SizedBox(height: NocturneSpacing.rowGap),
          EnergyConsumptionChart(),
          SizedBox(height: NocturneSpacing.rowGap),
          EnergyProductionChart(),
          SizedBox(height: NocturneSpacing.rowGap),
          EnergyForecast7dSection(),
          SizedBox(height: NocturneSpacing.rowGap),
          EnergySystemStrip(),
        ],
      ),
    );
  }
}
