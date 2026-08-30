import 'package:flutter/material.dart';

import '../../widgets/settings/settings_save_controller.dart';
import '../../widgets/settings/settings_sub_page_scaffold.dart';
import '../../widgets/settings/temperature_entities_card.dart';

/// Entity mapping for the "Temperaturas" sheet, reached via
/// Definições → Temperaturas.
class TemperatureSettingsScreen extends StatefulWidget {
  const TemperatureSettingsScreen({super.key});

  @override
  State<TemperatureSettingsScreen> createState() => _TemperatureSettingsScreenState();
}

class _TemperatureSettingsScreenState extends State<TemperatureSettingsScreen> {
  final _saveController = SettingsSaveController();

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubPageScaffold(
      title: 'Temperaturas',
      saveController: _saveController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: TemperatureEntitiesCard(saveController: _saveController)),
        ),
      ],
    );
  }
}
