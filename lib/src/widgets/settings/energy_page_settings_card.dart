import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/energy_page_settings_provider.dart';
import '../../providers/energy_page_settings_store.dart';
import '../../theme/nocturne_theme.dart';
import '../entity_id_field.dart';
import '../keyboard_text_field.dart';
import '../on_screen_keyboard_controller.dart';
import 'settings_save_controller.dart';

const _forecastDayLabels = ['Hoje', 'Amanhã', 'D+3', 'D+4', 'D+5', 'D+6', 'D+7'];
const _forecastDayHints = [
  'sensor.solcast_pv_forecast_forecast_today',
  'sensor.solcast_pv_forecast_forecast_tomorrow',
  'sensor.solcast_pv_forecast_forecast_d3',
  'sensor.solcast_pv_forecast_forecast_d4',
  'sensor.solcast_pv_forecast_forecast_d5',
  'sensor.solcast_pv_forecast_forecast_d6',
  'sensor.solcast_pv_forecast_forecast_d7',
];

/// Settings section for the full-page "Energia" tab — installed system
/// facts, tariffs, and the optional inverter/weather/Solcast entities its
/// KPI row, system strip and 7-day forecast read. A plain mutable draft
/// (not `EnergyPageConfig.copyWith`) for the same reason `EnergyEntitiesCard`
/// uses one for its sensor rows: several fields here are nullable
/// non-`String` types, where an `existing ?? this.existing`-style
/// `copyWith` can never actually clear a field back to null.
class EnergyPageSettingsCard extends ConsumerStatefulWidget {
  const EnergyPageSettingsCard({super.key, this.saveController});

  final SettingsSaveController? saveController;

  @override
  ConsumerState<EnergyPageSettingsCard> createState() => _EnergyPageSettingsCardState();
}

class _EnergyPageSettingsCardState extends ConsumerState<EnergyPageSettingsCard> {
  late double? _installedKwp;
  late int? _panelCount;
  late String _panelOrientation;
  late String _importPriceEntityId;
  late String _exportPriceEntityId;
  late String _inverterStatusEntityId;
  late String _inverterTemperatureEntityId;
  late String _inverterEfficiencyEntityId;
  late String _weatherEntityId;
  late DateTime? _lastCleaningDate;
  late DateTime? _nextCleaningDate;
  late List<String> _forecastDayEntityIds;

  @override
  void initState() {
    super.initState();
    final config = ref.read(energyPageConfigProvider);
    _installedKwp = config.installedKwp;
    _panelCount = config.panelCount;
    _panelOrientation = config.panelOrientation ?? '';
    _importPriceEntityId = config.importPriceEntityId ?? '';
    _exportPriceEntityId = config.exportPriceEntityId ?? '';
    _inverterStatusEntityId = config.inverterStatusEntityId ?? '';
    _inverterTemperatureEntityId = config.inverterTemperatureEntityId ?? '';
    _inverterEfficiencyEntityId = config.inverterEfficiencyEntityId ?? '';
    _weatherEntityId = config.weatherEntityId ?? '';
    _lastCleaningDate = config.lastCleaningDate;
    _nextCleaningDate = config.nextCleaningDate;
    _forecastDayEntityIds = [for (var i = 0; i < 7; i++) config.forecastDayEntityIds[i] ?? ''];
    widget.saveController?.bind(_save);
  }

  void _setSaved(bool value) => widget.saveController?.saved.value = value;

  void _touch(VoidCallback apply) {
    setState(() {
      apply();
      _setSaved(false);
    });
  }

  Future<void> _save() async {
    final config = EnergyPageConfig(
      installedKwp: _installedKwp,
      panelCount: _panelCount,
      panelOrientation: _panelOrientation,
      importPriceEntityId: _importPriceEntityId,
      exportPriceEntityId: _exportPriceEntityId,
      inverterStatusEntityId: _inverterStatusEntityId,
      inverterTemperatureEntityId: _inverterTemperatureEntityId,
      inverterEfficiencyEntityId: _inverterEfficiencyEntityId,
      weatherEntityId: _weatherEntityId,
      lastCleaningDate: _lastCleaningDate,
      nextCleaningDate: _nextCleaningDate,
      forecastDayEntityIds: _forecastDayEntityIds,
    );
    try {
      await ref.read(energyPageSettingsStoreProvider).save(config);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao guardar: $error'), backgroundColor: NocturneColors.red));
      return;
    }
    ref.read(energyPageConfigProvider.notifier).state = config;
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
            const _SectionHeader(icon: Icons.solar_power_outlined, title: 'SISTEMA', subtitle: 'Dados fixos da instalação — não vêm de nenhum sensor.'),
            const SizedBox(height: 18),
            _DecimalField(label: 'Potência instalada (kWp)', suffix: 'kWp', initialValue: _installedKwp, onChanged: (v) => _touch(() => _installedKwp = v)),
            const SizedBox(height: 16),
            _IntField(label: 'Número de painéis', initialValue: _panelCount, onChanged: (v) => _touch(() => _panelCount = v)),
            const SizedBox(height: 16),
            _PlainTextField(
              label: 'Orientação',
              hint: 'sul 30°',
              initialValue: _panelOrientation,
              onChanged: (v) => _touch(() => _panelOrientation = v),
            ),

            const Divider(height: 44),

            const _SectionHeader(icon: Icons.euro_outlined, title: 'TARIFÁRIO', subtitle: 'Usado para calcular a poupança na página de Energia.'),
            const SizedBox(height: 18),
            EntityIdField(
              label: 'Preço da eletricidade importada',
              hint: 'sensor.preco_eletricidade',
              domainFilter: 'sensor',
              initialValue: _importPriceEntityId,
              onChanged: (v) => _touch(() => _importPriceEntityId = v),
            ),
            const SizedBox(height: 16),
            EntityIdField(
              label: 'Preço da eletricidade injetada',
              hint: 'sensor.preco_eletricidade_injetada',
              domainFilter: 'sensor',
              initialValue: _exportPriceEntityId,
              onChanged: (v) => _touch(() => _exportPriceEntityId = v),
            ),

            const Divider(height: 44),

            const _SectionHeader(icon: Icons.developer_board_outlined, title: 'INVERSOR', subtitle: 'Opcional — em branco mostra "--" na faixa de sistema.'),
            const SizedBox(height: 18),
            EntityIdField(
              label: 'Estado do inversor',
              hint: 'sensor.inverter_status',
              initialValue: _inverterStatusEntityId,
              onChanged: (v) => _touch(() => _inverterStatusEntityId = v),
            ),
            const SizedBox(height: 16),
            EntityIdField(
              label: 'Temperatura do inversor',
              hint: 'sensor.inverter_temperature',
              domainFilter: 'sensor',
              initialValue: _inverterTemperatureEntityId,
              onChanged: (v) => _touch(() => _inverterTemperatureEntityId = v),
            ),
            const SizedBox(height: 16),
            EntityIdField(
              label: 'Eficiência do inversor',
              hint: 'sensor.inverter_efficiency',
              domainFilter: 'sensor',
              initialValue: _inverterEfficiencyEntityId,
              onChanged: (v) => _touch(() => _inverterEfficiencyEntityId = v),
            ),

            const Divider(height: 44),

            const _SectionHeader(
              icon: Icons.wb_cloudy_outlined,
              title: 'PREVISÃO SOLAR',
              subtitle: 'Um sensor de previsão diária (ex. Solcast) por dia, hoje primeiro. O de hoje também alimenta o gráfico "previsto" por hora, se tiver o atributo detailedForecast.',
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < 7; i++) ...[
              EntityIdField(
                label: '${_forecastDayLabels[i]} (kWh previstos)',
                hint: _forecastDayHints[i],
                domainFilter: 'sensor',
                initialValue: _forecastDayEntityIds[i],
                onChanged: (v) => _touch(() => _forecastDayEntityIds[i] = v),
              ),
              const SizedBox(height: 16),
            ],
            _FieldWithDescription(
              description: 'Opcional — só usado se a entidade ainda expuser o atributo "forecast" (condição + temperatura máxima por dia).',
              field: EntityIdField(
                label: 'Entidade de meteorologia',
                hint: 'weather.casa',
                domainFilter: 'weather',
                initialValue: _weatherEntityId,
                onChanged: (v) => _touch(() => _weatherEntityId = v),
              ),
            ),

            const Divider(height: 44),

            const _SectionHeader(icon: Icons.cleaning_services_outlined, title: 'MANUTENÇÃO', subtitle: 'Datas manuais — não há sensor de limpeza de painéis.'),
            const SizedBox(height: 18),
            _DateField(label: 'Última limpeza', value: _lastCleaningDate, onChanged: (v) => _touch(() => _lastCleaningDate = v)),
            const SizedBox(height: 16),
            _DateField(label: 'Próxima limpeza', value: _nextCleaningDate, onChanged: (v) => _touch(() => _nextCleaningDate = v)),
          ],
        ),
      ),
    );
  }
}

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
        Row(children: [Icon(icon, size: 20, color: NocturneColors.accent), const SizedBox(width: 8), Text(title, style: NocturneText.cardKicker)]),
        const SizedBox(height: 6),
        Text(subtitle, style: NocturneText.body),
      ],
    );
  }
}

class _FieldWithDescription extends StatelessWidget {
  const _FieldWithDescription({required this.field, required this.description});

  final Widget field;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [field, const SizedBox(height: 6), Padding(padding: const EdgeInsets.only(left: 2), child: Text(description, style: NocturneText.caption))],
    );
  }
}

/// A free-form text field (orientation) — keyboard-wired the same way
/// `EnergyEntitiesCard`'s sensor-name field is, via a direct controller
/// listener rather than `TextField.onChanged` (see `keyboard_text_field.dart`
/// for why: the on-screen keyboard's key taps mutate the controller
/// directly, which doesn't reliably reach `onChanged` on this app's target).
class _PlainTextField extends StatefulWidget {
  const _PlainTextField({required this.label, required this.hint, required this.initialValue, required this.onChanged});

  final String label;
  final String hint;
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
        hintText: widget.hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// A nullable-double field (kWp, €/kWh) — digits plus a single decimal
/// point, wired into the on-screen keyboard via a direct controller
/// listener, same reasoning/pattern as `EnergyEntitiesCard`'s `_ThresholdField`.
class _DecimalField extends StatefulWidget {
  const _DecimalField({required this.label, required this.suffix, required this.initialValue, required this.onChanged});

  final String label;
  final String suffix;
  final double? initialValue;
  final ValueChanged<double?> onChanged;

  @override
  State<_DecimalField> createState() => _DecimalFieldState();
}

class _DecimalFieldState extends State<_DecimalField> {
  late final _controller = TextEditingController(text: widget.initialValue == null ? '' : _plain(widget.initialValue!));
  final _focusNode = FocusNode();

  String _plain(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    widget.onChanged(text.isEmpty ? null : double.tryParse(text));
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(fontSize: 16),
        suffixText: widget.suffix,
        suffixStyle: NocturneText.unitSuffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// A nullable-int field (panel count) — same pattern as `_DecimalField`
/// without the decimal point.
class _IntField extends StatefulWidget {
  const _IntField({required this.label, required this.initialValue, required this.onChanged});

  final String label;
  final int? initialValue;
  final ValueChanged<int?> onChanged;

  @override
  State<_IntField> createState() => _IntFieldState();
}

class _IntFieldState extends State<_IntField> {
  late final _controller = TextEditingController(text: widget.initialValue?.toString() ?? '');
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    widget.onChanged(text.isEmpty ? null : int.tryParse(text));
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

const _monthAbbrevPt = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

/// A tap-to-open date field — this kiosk's on-screen keyboard has no date
/// entry mode, so this uses Flutter's own touch-driven `showDatePicker`
/// instead of typed input.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onChanged});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final text = value == null ? 'Não definida' : '${value.day} ${_monthAbbrevPt[value.month - 1]} ${value.year}';
    return InkWell(
      borderRadius: BorderRadius.circular(NocturneRadii.sm),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 3),
          lastDate: DateTime(now.year + 3),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 16),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined, size: 20)
              : IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => onChanged(null)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: const OutlineInputBorder(),
        ),
        child: Text(text, style: const TextStyle(fontSize: 17)),
      ),
    );
  }
}
