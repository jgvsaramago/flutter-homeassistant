import 'package:flutter/material.dart';

import '../../widgets/settings/energy_entities_card.dart';
import '../../widgets/settings/settings_save_controller.dart';
import '../../widgets/settings/settings_sub_page_scaffold.dart';

/// Entity mapping for the Homepage's "Energia" card, reached via
/// Definições → Cartão de Energia. `EnergyEntitiesCard` covers everything —
/// grid/solar/battery/home entities, zero thresholds, and the individual
/// sensors — behind one shared save, so there's exactly one floating
/// "Guardar" on this page.
class EnergySettingsScreen extends StatefulWidget {
  const EnergySettingsScreen({super.key});

  @override
  State<EnergySettingsScreen> createState() => _EnergySettingsScreenState();
}

class _EnergySettingsScreenState extends State<EnergySettingsScreen> {
  final _saveController = SettingsSaveController();

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubPageScaffold(
      title: 'Cartão de Energia',
      saveController: _saveController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: EnergyEntitiesCard(saveController: _saveController)),
        ),
      ],
    );
  }
}
