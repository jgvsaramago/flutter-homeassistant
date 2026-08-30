import 'package:flutter/material.dart';

import '../../widgets/settings/rooms_card.dart';
import '../../widgets/settings/settings_save_controller.dart';
import '../../widgets/settings/settings_sub_page_scaffold.dart';

/// Room list for the Divisões page, reached via Definições → Divisões.
class RoomsSettingsScreen extends StatefulWidget {
  const RoomsSettingsScreen({super.key});

  @override
  State<RoomsSettingsScreen> createState() => _RoomsSettingsScreenState();
}

class _RoomsSettingsScreenState extends State<RoomsSettingsScreen> {
  final _saveController = SettingsSaveController();

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubPageScaffold(
      title: 'Divisões',
      saveController: _saveController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: RoomsCard(saveController: _saveController)),
        ),
      ],
    );
  }
}
