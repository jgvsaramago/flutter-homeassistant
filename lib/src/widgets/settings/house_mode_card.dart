import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/house_mode_provider.dart';
import '../../providers/house_mode_store.dart';
import '../../theme/nocturne_theme.dart';
import '../entity_id_field.dart';
import 'settings_save_controller.dart';

/// Settings section letting the user point the Homepage's house-mode chip
/// at a real HA `input_select` entity (e.g. "Casa" / "Fora" / "Férias").
class HouseModeCard extends ConsumerStatefulWidget {
  const HouseModeCard({super.key, this.saveController});

  /// When set, this card's save button floats at the page level instead of
  /// rendering inline — see `SettingsSaveController`.
  final SettingsSaveController? saveController;

  @override
  ConsumerState<HouseModeCard> createState() => _HouseModeCardState();
}

class _HouseModeCardState extends ConsumerState<HouseModeCard> {
  late HouseModeConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(houseModeConfigProvider);
    widget.saveController?.bind(_save);
  }

  void _setSaved(bool value) => widget.saveController?.saved.value = value;

  Future<void> _save() async {
    try {
      await ref.read(houseModeStoreProvider).save(_draft);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao guardar: $error'), backgroundColor: NocturneColors.red));
      return;
    }
    ref.read(houseModeConfigProvider.notifier).state = _draft;
    if (!mounted) return;
    _setSaved(true);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.house_outlined, size: 20, color: NocturneColors.accent),
                const SizedBox(width: 8),
                Text('MODO DA CASA', style: NocturneText.cardKicker),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Entidade input_select mostrada como seletor de modo na Homepage. '
              'Cria-a em Definições → Ajudantes → Adicionar ajudante → Lista suspensa na tua instância HA, '
              'com as opções que quiseres (ex.: Casa, Fora, Férias, Noite).',
              style: NocturneText.body,
            ),
            const SizedBox(height: 18),
            EntityIdField(
              label: 'Modo da casa (opcional)',
              hint: 'input_select.modo_da_casa',
              initialValue: _draft.entityId,
              domainFilter: 'input_select',
              onChanged: (v) {
                setState(() {
                  _draft = _draft.copyWith(entityId: v);
                  _setSaved(false);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
