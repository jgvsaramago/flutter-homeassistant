import 'package:flutter/material.dart';

import '../../widgets/settings/house_mode_card.dart';
import '../../widgets/settings/settings_save_controller.dart';
import '../../widgets/settings/settings_sub_page_scaffold.dart';

/// House-mode entity, reached via Definições → Modo da Casa.
class HouseModeSettingsScreen extends StatefulWidget {
  const HouseModeSettingsScreen({super.key});

  @override
  State<HouseModeSettingsScreen> createState() => _HouseModeSettingsScreenState();
}

class _HouseModeSettingsScreenState extends State<HouseModeSettingsScreen> {
  final _saveController = SettingsSaveController();

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubPageScaffold(
      title: 'Modo da Casa',
      saveController: _saveController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: HouseModeCard(saveController: _saveController)),
        ),
      ],
    );
  }
}
