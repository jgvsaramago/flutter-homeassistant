import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/energy_entities_provider.dart';
import '../../providers/energy_entities_store.dart';
import '../../providers/individual_sensors_provider.dart';
import '../../providers/individual_sensors_store.dart';
import '../../theme/nocturne_theme.dart';
import '../entity_id_field.dart';
import '../individual_sensor_icon.dart';
import '../keyboard_text_field.dart';
import '../on_screen_keyboard_controller.dart';
import 'settings_save_controller.dart';

const _maxSensors = 4;

/// One individual-sensor row being edited — a synthetic [id] (not the
/// sensor's name, which is mutable and briefly empty/duplicated while
/// typing) gives each row a stable [Key] across add/remove, so
/// `EntityIdField`'s own internal `TextEditingController` stays attached to
/// the right row instead of scrambling when the list above or below it
/// changes length. Same pattern as `CalendarEntitiesCard`'s `_DraftEntry`.
class _SensorDraftEntry {
  _SensorDraftEntry({required this.id, required this.name, required this.powerEntityId, required this.temperatureEntityId, required this.icon});

  final int id;
  String name;
  String powerEntityId;
  String temperatureEntityId;
  IndividualSensorIconKey icon;

  /// True when the user has put something into this row besides the name —
  /// used to warn before a blank-named row silently vanishes on save,
  /// rather than after, when there'd be nothing left on screen explaining
  /// where the entities they'd typed went.
  bool get hasEntityData => powerEntityId.trim().isNotEmpty || temperatureEntityId.trim().isNotEmpty;
}

/// Settings section letting the user point the Homepage's energy-flow card
/// at real HA entities — it has no household-specific entity ids baked in
/// (unlike the rest of this app's climate/EV widgets), so without this it
/// would show nothing but "--" forever. Also holds each node's zero
/// threshold, and the card's up-to-4 individual-sensor device nodes
/// (washing machine, fridge, water heater...). Everything on this one card
/// — entities, thresholds, and sensors — shares a single "Guardar", same as
/// every other multi-section settings card in this app (`EvCarsCard`'s two
/// car sections, for instance): two independent save buttons on one screen
/// invites saving one half and believing both were saved.
class EnergyEntitiesCard extends ConsumerStatefulWidget {
  const EnergyEntitiesCard({super.key, this.saveController});

  /// When set, this card's save button floats at the page level instead of
  /// rendering inline — see `SettingsSaveController`.
  final SettingsSaveController? saveController;

  @override
  ConsumerState<EnergyEntitiesCard> createState() => _EnergyEntitiesCardState();
}

class _EnergyEntitiesCardState extends ConsumerState<EnergyEntitiesCard> {
  late EnergyEntityConfig _draft;
  late List<_SensorDraftEntry> _sensorsDraft;
  int _nextSensorId = 0;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(energyEntityConfigProvider);
    _sensorsDraft = [
      for (final s in ref.read(individualSensorsProvider))
        _SensorDraftEntry(id: _nextSensorId++, name: s.name, powerEntityId: s.powerEntityId ?? '', temperatureEntityId: s.temperatureEntityId ?? '', icon: s.icon),
    ];
    widget.saveController?.bind(_save);
  }

  void _setSaved(bool value) => widget.saveController?.saved.value = value;

  Future<void> _save() async {
    final sensors = [
      for (final e in _sensorsDraft)
        if (e.name.trim().isNotEmpty)
          IndividualSensorConfig(name: e.name.trim(), powerEntityId: e.powerEntityId, temperatureEntityId: e.temperatureEntityId, icon: e.icon),
    ];
    // A row with an entity typed in but no name would otherwise vanish
    // silently right here (the filter above drops it) — surface that
    // instead of just losing it, since "I typed an entity id and it's
    // gone" is indistinguishable from a real save failure otherwise.
    final droppedCount = _sensorsDraft.where((e) => e.name.trim().isEmpty && e.hasEntityData).length;
    try {
      await ref.read(energyEntitiesStoreProvider).save(_draft);
      await ref.read(individualSensorsStoreProvider).save(sensors);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao guardar: $error'), backgroundColor: NocturneColors.red));
      return;
    }
    ref.read(energyEntityConfigProvider.notifier).state = _draft;
    ref.read(individualSensorsProvider.notifier).state = sensors;
    if (!mounted) return;
    _setSaved(true);
    if (droppedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            droppedCount == 1
                ? '1 sensor sem nome não foi guardado — adicione um nome e guarde outra vez.'
                : '$droppedCount sensores sem nome não foram guardados — adicione um nome e guarde outra vez.',
          ),
          backgroundColor: NocturneColors.solarMark,
        ),
      );
    }
  }

  void _update(EnergyEntityConfig Function(EnergyEntityConfig draft) apply) {
    setState(() {
      _draft = apply(_draft);
      _setSaved(false);
    });
  }

  void _addSensor() {
    if (_sensorsDraft.length >= _maxSensors) return;
    setState(() {
      _sensorsDraft = [
        ..._sensorsDraft,
        _SensorDraftEntry(id: _nextSensorId++, name: '', powerEntityId: '', temperatureEntityId: '', icon: IndividualSensorIconKey.plug),
      ];
      _setSaved(false);
    });
  }

  void _removeSensor(int id) {
    setState(() {
      _sensorsDraft = _sensorsDraft.where((e) => e.id != id).toList();
      _setSaved(false);
    });
  }

  void _updateSensor(int id, void Function(_SensorDraftEntry entry) apply) {
    setState(() {
      apply(_sensorsDraft.firstWhere((e) => e.id == id));
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
            const _SectionHeader(
              icon: Icons.bolt_outlined,
              title: 'ENTIDADES',
              subtitle: 'Sensores de potência devem reportar W ou kW.',
            ),
            const SizedBox(height: 18),
            _FieldWithDescription(
              description: 'Sinal positivo = a importar da rede; negativo = a exportar.',
              field: EntityIdField(
                label: 'Potência da rede',
                hint: 'sensor.grid_power',
                initialValue: _draft.gridPowerEntityId,
                onChanged: (v) => _update((c) => c.copyWith(gridPowerEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Produção solar instantânea (sempre ≥ 0).',
              field: EntityIdField(
                label: 'Potência solar',
                hint: 'sensor.solar_power',
                initialValue: _draft.solarPowerEntityId,
                onChanged: (v) => _update((c) => c.copyWith(solarPowerEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Sinal positivo = a descarregar; negativo = a carregar.',
              field: EntityIdField(
                label: 'Potência da bateria',
                hint: 'sensor.battery_power',
                initialValue: _draft.batteryPowerEntityId,
                onChanged: (v) => _update((c) => c.copyWith(batteryPowerEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Percentagem de carga da bateria, 0-100%.',
              field: EntityIdField(
                label: 'Carga da bateria (SOC)',
                hint: 'sensor.battery_soc',
                initialValue: _draft.batterySocEntityId,
                onChanged: (v) => _update((c) => c.copyWith(batterySocEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Consumo total da casa (sempre ≥ 0).',
              field: EntityIdField(
                label: 'Potência da casa',
                hint: 'sensor.home_power',
                initialValue: _draft.homePowerEntityId,
                onChanged: (v) => _update((c) => c.copyWith(homePowerEntityId: v)),
              ),
            ),

            const Divider(height: 44),

            const _SectionHeader(
              icon: Icons.exposure_zero,
              title: 'LIMIAR DE ZERO',
              subtitle: 'Leituras dentro deste número de watts mostram 0 W em vez do ruído natural do sensor.',
            ),
            const SizedBox(height: 18),
            _FieldWithDescription(
              description: 'Abaixo deste valor, a rede mostra 0 W e nenhuma seta de direção.',
              field: _ThresholdField(
                label: 'Rede',
                initialValue: _draft.gridZeroThresholdW,
                onChanged: (v) => _update((c) => c.copyWith(gridZeroThresholdW: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Abaixo deste valor, o solar mostra 0 W e a ligação fica inativa.',
              field: _ThresholdField(
                label: 'Solar',
                initialValue: _draft.solarZeroThresholdW,
                onChanged: (v) => _update((c) => c.copyWith(solarZeroThresholdW: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Abaixo deste valor, a bateria mostra 0 W e nenhuma seta de direção.',
              field: _ThresholdField(
                label: 'Bateria',
                initialValue: _draft.batteryZeroThresholdW,
                onChanged: (v) => _update((c) => c.copyWith(batteryZeroThresholdW: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Abaixo deste valor, a casa mostra 0 W.',
              field: _ThresholdField(
                label: 'Casa',
                initialValue: _draft.homeZeroThresholdW,
                onChanged: (v) => _update((c) => c.copyWith(homeZeroThresholdW: v)),
              ),
            ),

            const Divider(height: 44),

            const _SectionHeader(
              icon: Icons.dashboard_customize_outlined,
              title: 'SENSORES INDIVIDUAIS',
              subtitle: 'Até 4 circuitos (máquina de lavar, frigorífico, termoacumulador...), cada um com o seu sensor de potência. A ordem aqui é a ordem no cartão.',
            ),
            const SizedBox(height: 18),
            for (final entry in _sensorsDraft) ...[
              _SensorRow(
                key: ValueKey(entry.id),
                entry: entry,
                onNameChanged: (v) => _updateSensor(entry.id, (e) => e.name = v),
                onPowerEntityChanged: (v) => _updateSensor(entry.id, (e) => e.powerEntityId = v),
                onTemperatureEntityChanged: (v) => _updateSensor(entry.id, (e) => e.temperatureEntityId = v),
                onIconChanged: (icon) => _updateSensor(entry.id, (e) => e.icon = icon),
                onRemove: () => _removeSensor(entry.id),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _sensorsDraft.length >= _maxSensors ? null : _addSensor,
              icon: const Icon(Icons.add),
              label: Text(_sensorsDraft.length >= _maxSensors ? 'Máximo de $_maxSensors sensores' : 'Adicionar sensor'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A kicker-style title (matching the "ENERGIA" label on the card this
/// settings page configures) plus an explanatory line, marking the start of
/// one visually distinct group of related fields.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

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
        const SizedBox(height: 6),
        Text(subtitle, style: NocturneText.body),
      ],
    );
  }
}

/// Pairs a settings field with a persistent one-line explanation — unlike a
/// hint, this stays visible once the field has a value, so "what does this
/// do" doesn't disappear the moment it's filled in.
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
        Padding(padding: const EdgeInsets.only(left: 2), child: Text(description, style: NocturneText.caption)),
      ],
    );
  }
}

/// A whole-watts numeric field for one node's zero threshold, wired into
/// the on-screen keyboard the same way `EntityIdField` is — this kiosk has
/// no physical keyboard, and the on-screen one is a single fixed
/// alphanumeric layout with no numeric-only mode, so non-digit input is
/// filtered here instead.
class _ThresholdField extends StatefulWidget {
  const _ThresholdField({required this.label, required this.initialValue, required this.onChanged});

  final String label;
  final double initialValue;
  final ValueChanged<double> onChanged;

  @override
  State<_ThresholdField> createState() => _ThresholdFieldState();
}

class _ThresholdFieldState extends State<_ThresholdField> {
  late final _controller = TextEditingController(text: widget.initialValue.round().toString());
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  void _onTextChanged() {
    final parsed = int.tryParse(_controller.text);
    if (parsed != null) widget.onChanged(parsed.toDouble());
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      OnScreenKeyboardController.instance.attach(_controller);
    } else {
      OnScreenKeyboardController.instance.detach(_controller);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(fontSize: 16),
        suffixText: 'W',
        suffixStyle: NocturneText.unitSuffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// One individual-sensor row: name, icon picker, power entity, optional
/// temperature entity, and a remove button.
class _SensorRow extends StatelessWidget {
  const _SensorRow({
    super.key,
    required this.entry,
    required this.onNameChanged,
    required this.onPowerEntityChanged,
    required this.onTemperatureEntityChanged,
    required this.onIconChanged,
    required this.onRemove,
  });

  final _SensorDraftEntry entry;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onPowerEntityChanged;
  final ValueChanged<String> onTemperatureEntityChanged;
  final ValueChanged<IndividualSensorIconKey> onIconChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: NocturneColors.inset, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _SensorNameField(initialValue: entry.name, onChanged: onNameChanged)),
              IconButton(onPressed: onRemove, icon: Icon(Icons.delete_outline, color: NocturneColors.neutral500), tooltip: 'Remover'),
            ],
          ),
          if (entry.name.trim().isEmpty && entry.hasEntityData) ...[
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.only(left: 2),
              child: Text('Sem nome — este sensor não vai ser guardado.', style: TextStyle(fontSize: 14, color: NocturneColors.solarMark)),
            ),
          ],
          const SizedBox(height: 12),
          _IconPicker(selected: entry.icon, onSelect: onIconChanged),
          const SizedBox(height: 12),
          EntityIdField(
            label: 'Potência',
            hint: 'sensor.washing_machine_power',
            initialValue: entry.powerEntityId,
            domainFilter: 'sensor',
            onChanged: onPowerEntityChanged,
          ),
          const SizedBox(height: 12),
          EntityIdField(
            label: 'Temperatura (opcional)',
            hint: 'sensor.water_heater_temperature',
            initialValue: entry.temperatureEntityId,
            domainFilter: 'sensor',
            onChanged: onTemperatureEntityChanged,
          ),
        ],
      ),
    );
  }
}

/// A free-form field for the sensor's display name — unlike the entity
/// fields, this isn't an HA id, so it's a plain keyboard-wired text field
/// rather than `EntityIdField`'s autocomplete. Same shape as
/// `EvCarsCard`'s own private `_PlainTextField`.
class _SensorNameField extends StatefulWidget {
  const _SensorNameField({required this.initialValue, required this.onChanged});

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_SensorNameField> createState() => _SensorNameFieldState();
}

class _SensorNameFieldState extends State<_SensorNameField> {
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
      decoration: const InputDecoration(
        labelText: 'Nome',
        labelStyle: TextStyle(fontSize: 16),
        hintText: 'Máquina de lavar',
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelect});

  final IndividualSensorIconKey selected;
  final ValueChanged<IndividualSensorIconKey> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final key in IndividualSensorIconKey.values) _IconSwatch(iconKey: key, active: key == selected, onTap: () => onSelect(key))],
    );
  }
}

class _IconSwatch extends StatelessWidget {
  const _IconSwatch({required this.iconKey, required this.active, required this.onTap});

  final IndividualSensorIconKey iconKey;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: iconKey.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? NocturneColors.accent.withValues(alpha: 0.18) : NocturneColors.neutral800,
            border: active ? Border.all(color: NocturneColors.accent, width: 2) : null,
          ),
          child: individualSensorIcon(iconKey, size: 22, color: active ? NocturneColors.accent : NocturneColors.neutral300),
        ),
      ),
    );
  }
}
