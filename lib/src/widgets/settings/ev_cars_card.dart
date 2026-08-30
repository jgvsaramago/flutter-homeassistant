import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ev_cars_provider.dart';
import '../../providers/ev_cars_store.dart';
import '../../theme/nocturne_theme.dart';
import '../entity_id_field.dart';
import '../keyboard_text_field.dart';
import 'settings_save_controller.dart';

/// Settings section letting the user name the Homepage's two EV cards and
/// point each at real HA entities — same shape as `EnergyEntitiesCard`, just
/// for a fixed pair of cars instead of one set of energy nodes.
class EvCarsCard extends ConsumerStatefulWidget {
  const EvCarsCard({super.key, this.saveController});

  /// When set, this card's save button floats at the page level instead of
  /// rendering inline — see `SettingsSaveController`.
  final SettingsSaveController? saveController;

  @override
  ConsumerState<EvCarsCard> createState() => _EvCarsCardState();
}

class _EvCarsCardState extends ConsumerState<EvCarsCard> {
  late EvCarsConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(evCarsConfigProvider);
    widget.saveController?.bind(_save);
  }

  void _setSaved(bool value) => widget.saveController?.saved.value = value;

  Future<void> _save() async {
    await ref.read(evCarsStoreProvider).save(_draft);
    ref.read(evCarsConfigProvider.notifier).state = _draft;
    if (!mounted) return;
    _setSaved(true);
  }

  void _updateLeft(EvCarConfig Function(EvCarConfig draft) apply) {
    setState(() {
      _draft = _draft.copyWith(left: apply(_draft.left));
      _setSaved(false);
    });
  }

  void _updateRight(EvCarConfig Function(EvCarConfig draft) apply) {
    setState(() {
      _draft = _draft.copyWith(right: apply(_draft.right));
      _setSaved(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CarSection(
              icon: Icons.electric_car_outlined,
              title: 'CARTÃO ESQUERDO',
              car: _draft.left,
              onUpdate: _updateLeft,
            ),
            const Divider(height: 44),
            _CarSection(
              icon: Icons.electric_car_outlined,
              title: 'CARTÃO DIREITO',
              car: _draft.right,
              onUpdate: _updateRight,
            ),
          ],
        ),
      ),
    );
  }
}

/// One car's whole field group: name plus its three entities.
class _CarSection extends StatelessWidget {
  const _CarSection({
    required this.icon,
    required this.title,
    required this.car,
    required this.onUpdate,
  });

  final IconData icon;
  final String title;
  final EvCarConfig car;
  final void Function(EvCarConfig Function(EvCarConfig draft) apply) onUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: NocturneColors.accent),
            const SizedBox(width: 8),
            Text(title, style: NocturneText.cardKicker),
          ],
        ),
        const SizedBox(height: 18),
        _PlainTextField(
          label: 'Nome',
          initialValue: car.name,
          onChanged: (v) => onUpdate((c) => c.copyWith(name: v)),
        ),
        const SizedBox(height: 16),
        _FieldWithDescription(
          description:
              'URL de uma foto do carro (ex.: um ficheiro em /config/www/ do '
              'Home Assistant, servido como http://<ha>/local/..., ou o '
              '"entity_picture" de uma entidade camera/image/person).',
          field: _PlainTextField(
            label: 'Foto (URL)',
            initialValue: car.photoUrl ?? '',
            onChanged: (v) => onUpdate((c) => c.copyWith(photoUrl: v)),
          ),
        ),
        const SizedBox(height: 16),
        _FieldWithDescription(
          description: 'Carga da bateria, 0-100%.',
          field: EntityIdField(
            label: 'Bateria',
            hint: 'sensor.car_battery',
            initialValue: car.batterySocEntityId,
            domainFilter: 'sensor',
            onChanged: (v) =>
                onUpdate((c) => c.copyWith(batterySocEntityId: v)),
          ),
        ),
        const SizedBox(height: 16),
        _FieldWithDescription(
          description: 'Autonomia restante, na unidade que o sensor reportar.',
          field: EntityIdField(
            label: 'Autonomia',
            hint: 'sensor.car_range',
            initialValue: car.rangeEntityId,
            domainFilter: 'sensor',
            onChanged: (v) => onUpdate((c) => c.copyWith(rangeEntityId: v)),
          ),
        ),
        const SizedBox(height: 16),
        _FieldWithDescription(
          description:
              'Um sensor cujo estado seja "on"/"charging" enquanto carrega.',
          field: EntityIdField(
            label: 'Estado de carregamento',
            hint: 'binary_sensor.car_charging',
            initialValue: car.chargingEntityId,
            onChanged: (v) => onUpdate((c) => c.copyWith(chargingEntityId: v)),
          ),
        ),
        const SizedBox(height: 16),
        _FieldWithDescription(
          description:
              'Um sensor cujo estado seja "on"/"connected" quando a ficha está ligada, mesmo sem carregar.',
          field: EntityIdField(
            label: 'Ficha ligada',
            hint: 'binary_sensor.car_plugged_in',
            initialValue: car.plugConnectedEntityId,
            onChanged: (v) =>
                onUpdate((c) => c.copyWith(plugConnectedEntityId: v)),
          ),
        ),
        const SizedBox(height: 16),
        _FieldWithDescription(
          description:
              'Energia carregada este mês, em kWh (ex.: um sensor "utility_meter" mensal).',
          field: EntityIdField(
            label: 'Energia do mês',
            hint: 'sensor.car_energy_this_month',
            initialValue: car.monthEnergyEntityId,
            domainFilter: 'sensor',
            onChanged: (v) =>
                onUpdate((c) => c.copyWith(monthEnergyEntityId: v)),
          ),
        ),
        const SizedBox(height: 16),
        _FieldWithDescription(
          description:
              'Variação da energia face ao mês anterior, em %. Um valor negativo mostra "-".',
          field: EntityIdField(
            label: 'Variação da energia',
            hint: 'sensor.car_energy_delta_percent',
            initialValue: car.monthEnergyDeltaEntityId,
            domainFilter: 'sensor',
            onChanged: (v) =>
                onUpdate((c) => c.copyWith(monthEnergyDeltaEntityId: v)),
          ),
        ),
        const SizedBox(height: 16),
        _FieldWithDescription(
          description: 'Custo da carga este mês, em euros.',
          field: EntityIdField(
            label: 'Custo do mês',
            hint: 'sensor.car_cost_this_month',
            initialValue: car.monthCostEntityId,
            domainFilter: 'sensor',
            onChanged: (v) => onUpdate((c) => c.copyWith(monthCostEntityId: v)),
          ),
        ),
        const SizedBox(height: 16),
        _FieldWithDescription(
          description:
              'Variação do custo face ao mês anterior, em euros. Um valor negativo mostra "-".',
          field: EntityIdField(
            label: 'Variação do custo',
            hint: 'sensor.car_cost_delta_eur',
            initialValue: car.monthCostDeltaEntityId,
            domainFilter: 'sensor',
            onChanged: (v) =>
                onUpdate((c) => c.copyWith(monthCostDeltaEntityId: v)),
          ),
        ),
      ],
    );
  }
}

/// A free-form field for literal copy (a display name, an image URL) —
/// unlike the entity fields, this isn't an HA id, so it's a plain
/// keyboard-wired text field rather than `EntityIdField`'s autocomplete.
class _PlainTextField extends StatefulWidget {
  const _PlainTextField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_PlainTextField> createState() => _PlainTextFieldState();
}

class _PlainTextFieldState extends State<_PlainTextField> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardTextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Pairs a settings field with a persistent one-line explanation — same as
/// `EnergyEntitiesCard`'s own private helper of the same name.
class _FieldWithDescription extends StatelessWidget {
  const _FieldWithDescription({required this.field, required this.description});

  final Widget field;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(description, style: NocturneText.caption),
        ),
      ],
    );
  }
}
