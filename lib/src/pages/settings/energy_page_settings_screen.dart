import 'package:flutter/material.dart';

import '../../widgets/settings/energy_page_settings_card.dart';
import '../../widgets/settings/settings_save_controller.dart';
import '../../widgets/settings/settings_sub_page_scaffold.dart';

/// Settings for the full-page "Energia" tab, reached via Definições →
/// Página de Energia — separate from `EnergySettingsScreen` (the compact
/// flow-card's grid/solar/battery/home entities), since this page adds a
/// second, larger set of concerns (system facts, tariffs, forecast/inverter
/// entities) that would otherwise crowd one already-long settings card.
class EnergyPageSettingsScreen extends StatefulWidget {
  const EnergyPageSettingsScreen({super.key});

  @override
  State<EnergyPageSettingsScreen> createState() => _EnergyPageSettingsScreenState();
}

class _EnergyPageSettingsScreenState extends State<EnergyPageSettingsScreen> {
  final _saveController = SettingsSaveController();

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubPageScaffold(
      title: 'Página de Energia',
      saveController: _saveController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: EnergyPageSettingsCard(saveController: _saveController)),
        ),
      ],
    );
  }
}
