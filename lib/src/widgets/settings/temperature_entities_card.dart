import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/temperature_entities_provider.dart';
import '../../theme/nocturne_theme.dart';
import '../entity_id_field.dart';
import '../../providers/temperature_entities_store.dart';
import 'settings_save_controller.dart';

/// Settings section letting the user point the Temperatures sheet at real
/// HA entities. The two temperature fields already have a working default
/// (this app's pre-existing hardcoded sensors); everything else — air
/// quality and exterior weather — has no household-specific entity baked
/// in, so it shows "--" until configured here.
class TemperatureEntitiesCard extends ConsumerStatefulWidget {
  const TemperatureEntitiesCard({super.key, this.saveController});

  /// When set, this card's save button floats at the page level instead of
  /// rendering inline — see `SettingsSaveController`.
  final SettingsSaveController? saveController;

  @override
  ConsumerState<TemperatureEntitiesCard> createState() => _TemperatureEntitiesCardState();
}

class _TemperatureEntitiesCardState extends ConsumerState<TemperatureEntitiesCard> {
  late TemperatureEntityConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(temperatureEntityConfigProvider);
    widget.saveController?.bind(_save);
  }

  void _setSaved(bool value) => widget.saveController?.saved.value = value;

  Future<void> _save() async {
    try {
      await ref.read(temperatureEntitiesStoreProvider).save(_draft);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao guardar: $error'), backgroundColor: NocturneColors.red));
      return;
    }
    ref.read(temperatureEntityConfigProvider.notifier).state = _draft;
    if (!mounted) return;
    _setSaved(true);
  }

  void _update(TemperatureEntityConfig Function(TemperatureEntityConfig draft) apply) {
    setState(() {
      _draft = apply(_draft);
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
            const _SectionHeader(icon: Icons.home_outlined, title: 'INTERIOR', subtitle: 'Temperatura, humidade e qualidade do ar interior.'),
            const SizedBox(height: 18),
            _FieldWithDescription(
              description: 'Leitura principal mostrada no cartão e no topo da folha.',
              field: EntityIdField(
                label: 'Temperatura interior',
                hint: 'sensor.temperatura_interior',
                initialValue: _draft.interiorTempEntityId,
                onChanged: (v) => _update((c) => c.copyWith(interiorTempEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Percentagem de humidade relativa.',
              field: EntityIdField(
                label: 'Humidade interior',
                hint: 'sensor.humidade_interior',
                initialValue: _draft.interiorHumidityEntityId,
                onChanged: (v) => _update((c) => c.copyWith(interiorHumidityEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Dióxido de carbono, em ppm.',
              field: EntityIdField(
                label: 'CO₂',
                hint: 'sensor.co2',
                initialValue: _draft.co2EntityId,
                onChanged: (v) => _update((c) => c.copyWith(co2EntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Partículas finas, em µg/m³.',
              field: EntityIdField(
                label: 'PM2.5',
                hint: 'sensor.pm25',
                initialValue: _draft.pm25EntityId,
                onChanged: (v) => _update((c) => c.copyWith(pm25EntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Compostos orgânicos voláteis, em mg/m³.',
              field: EntityIdField(
                label: 'VOC',
                hint: 'sensor.voc',
                initialValue: _draft.vocEntityId,
                onChanged: (v) => _update((c) => c.copyWith(vocEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Concentração de radão, em Bq/m³.',
              field: EntityIdField(
                label: 'Radão',
                hint: 'sensor.radao',
                initialValue: _draft.radonEntityId,
                onChanged: (v) => _update((c) => c.copyWith(radonEntityId: v)),
              ),
            ),

            const Divider(height: 44),

            const _SectionHeader(icon: Icons.wb_cloudy_outlined, title: 'EXTERIOR', subtitle: 'Temperatura e condições meteorológicas da estação exterior.'),
            const SizedBox(height: 18),
            _FieldWithDescription(
              description: 'Leitura principal mostrada no cartão e na folha.',
              field: EntityIdField(
                label: 'Temperatura exterior',
                hint: 'sensor.temperatura_exterior',
                initialValue: _draft.exteriorTempEntityId,
                onChanged: (v) => _update((c) => c.copyWith(exteriorTempEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Percentagem de humidade relativa exterior.',
              field: EntityIdField(
                label: 'Humidade exterior',
                hint: 'sensor.humidade_exterior',
                initialValue: _draft.exteriorHumidityEntityId,
                onChanged: (v) => _update((c) => c.copyWith(exteriorHumidityEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Precipitação acumulada hoje, em mm.',
              field: EntityIdField(
                label: 'Chuva hoje',
                hint: 'sensor.chuva_hoje',
                initialValue: _draft.rainEntityId,
                onChanged: (v) => _update((c) => c.copyWith(rainEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Velocidade do vento, em km/h.',
              field: EntityIdField(
                label: 'Vento',
                hint: 'sensor.vento',
                initialValue: _draft.windEntityId,
                onChanged: (v) => _update((c) => c.copyWith(windEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Rajada máxima, em km/h.',
              field: EntityIdField(
                label: 'Rajada máxima',
                hint: 'sensor.rajada_maxima',
                initialValue: _draft.gustEntityId,
                onChanged: (v) => _update((c) => c.copyWith(gustEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Pressão atmosférica, em hPa.',
              field: EntityIdField(
                label: 'Pressão',
                hint: 'sensor.pressao',
                initialValue: _draft.pressureEntityId,
                onChanged: (v) => _update((c) => c.copyWith(pressureEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Índice de radiação ultravioleta.',
              field: EntityIdField(
                label: 'Índice UV',
                hint: 'sensor.indice_uv',
                initialValue: _draft.uvEntityId,
                onChanged: (v) => _update((c) => c.copyWith(uvEntityId: v)),
              ),
            ),
            const SizedBox(height: 16),
            _FieldWithDescription(
              description: 'Estado do tempo em texto (ex.: "Chuva fraca") e a previsão de 7 dias da Homepage.',
              field: EntityIdField(
                label: 'Estado do tempo',
                hint: 'weather.estacao',
                domainFilter: 'weather',
                initialValue: _draft.weatherStateEntityId,
                onChanged: (v) => _update((c) => c.copyWith(weatherStateEntityId: v)),
              ),
            ),

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
