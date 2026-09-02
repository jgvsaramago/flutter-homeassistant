import 'package:flutter/material.dart';

import '../theme/nocturne_theme.dart';
import '../widgets/dashboard/calendar_card.dart';
import '../widgets/dashboard/climate_hero.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/energy_flow_card.dart';
import '../widgets/dashboard/ev_cars_row.dart';
import '../widgets/dashboard/media_player_card.dart';
import '../widgets/dashboard/weekly_forecast_card.dart';
import '../widgets/shell/app_nav_bar.dart';

/// The "Homepage" tab: the Nocturne-design dashboard — greeting/clock, a
/// climate hero (indoor/outdoor readings + status pills), EV charging,
/// 7-day weather, calendar + media player, and the live energy-flow
/// diagram.
///
/// Unlike every other tab, this one never scrolls: it's a fixed grid that
/// always fits the viewport exactly. Every row above the energy card sizes
/// to its own content; the energy card is the sole [Expanded] row, so it
/// stretches or shrinks to take up whatever height is actually left rather
/// than overflowing off-screen or leaving a scrollable gap. The bottom
/// padding equals [AppNavBar.floatingClearance] (the floating nav bar's
/// real footprint), so the card's live content never sits under the bar.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// This page's own row gap (18px) — bumped from [NocturneSpacing.rowGap]
  /// (16px, still used by every other screen) as part of the Homepage
  /// redesign that introduced the climate hero and range-bar forecast.
  static const _rowGap = 18.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        NocturneSpacing.pagePadding.left,
        NocturneSpacing.pagePadding.top,
        NocturneSpacing.pagePadding.right,
        AppNavBar.floatingClearance + MediaQuery.paddingOf(context).bottom + _rowGap,
      ),
      child: const Column(
        children: [
          DashboardHeader(),
          SizedBox(height: _rowGap),
          ClimateHero(),
          SizedBox(height: _rowGap),
          EvCarsRow(),
          SizedBox(height: _rowGap),
          WeeklyForecastCard(),
          SizedBox(height: _rowGap),
          SizedBox(
            height: 336,
            child: Row(
              children: [
                CalendarCard(),
                SizedBox(width: 16),
                Expanded(child: MediaPlayerCard()),
              ],
            ),
          ),
          SizedBox(height: _rowGap),
          Expanded(child: EnergyFlowCard()),
        ],
      ),
    );
  }
}
