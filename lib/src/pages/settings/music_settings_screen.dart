import 'package:flutter/material.dart';

import '../../widgets/settings/mass_connection_card.dart';
import '../../widgets/settings/settings_save_controller.dart';
import '../../widgets/settings/settings_sub_page_scaffold.dart';

/// Music Assistant server connection, reached via Definições → Música.
class MusicSettingsScreen extends StatefulWidget {
  const MusicSettingsScreen({super.key});

  @override
  State<MusicSettingsScreen> createState() => _MusicSettingsScreenState();
}

class _MusicSettingsScreenState extends State<MusicSettingsScreen> {
  final _saveController = SettingsSaveController();

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubPageScaffold(
      title: 'Música',
      saveController: _saveController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: MassConnectionCard(saveController: _saveController)),
        ),
      ],
    );
  }
}
