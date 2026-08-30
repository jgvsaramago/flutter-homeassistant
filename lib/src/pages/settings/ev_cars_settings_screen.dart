import 'package:flutter/material.dart';

import '../../widgets/settings/ev_cars_card.dart';
import '../../widgets/settings/settings_save_controller.dart';
import '../../widgets/settings/settings_sub_page_scaffold.dart';

/// Entity mapping for the Homepage's two EV cards, reached via
/// Definições → Carros elétricos.
class EvCarsSettingsScreen extends StatefulWidget {
  const EvCarsSettingsScreen({super.key});

  @override
  State<EvCarsSettingsScreen> createState() => _EvCarsSettingsScreenState();
}

class _EvCarsSettingsScreenState extends State<EvCarsSettingsScreen> {
  final _saveController = SettingsSaveController();

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubPageScaffold(
      title: 'Carros elétricos',
      saveController: _saveController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: EvCarsCard(saveController: _saveController)),
        ),
      ],
    );
  }
}
