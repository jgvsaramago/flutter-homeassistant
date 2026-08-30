import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ha_client/ha_websocket_client.dart';
import '../../mass_client/mass_websocket_client.dart';
import '../../mqtt/mqtt_connection_status.dart';
import '../../providers/ha_providers.dart';
import '../../providers/mass_providers.dart';
import '../../theme/nocturne_theme.dart';
import 'calendar_settings_screen.dart';
import 'energy_page_settings_screen.dart';
import 'energy_settings_screen.dart';
import 'ev_cars_settings_screen.dart';
import 'music_settings_screen.dart';
import 'rooms_settings_screen.dart';
import 'temperature_settings_screen.dart';
import '../../widgets/settings/brightness_slider_card.dart';
import '../../widgets/settings/reboot_button_card.dart';
import '../../widgets/settings/settings_nav_tile.dart';
import '../../widgets/shell/app_nav_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(connectionConfigProvider);
    final connectionState = ref.watch(haConnectionStateProvider).value ?? HaConnectionState.disconnected;
    final entityCount = ref.watch(entitiesProvider).value?.length ?? 0;
    // Not watching massPlayersProvider here deliberately — Music Assistant
    // only ever connects once something actually needs it (see
    // MassConnectionCard's own comment), and this row is purely
    // informational, not another trigger to connect eagerly.
    final massConfig = ref.watch(massConnectionConfigProvider);
    final massState = ref.watch(massConnectionStateProvider).value ?? MassConnectionState.disconnected;

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.fromLTRB(18, 28, 18, 12), child: Text('Definições', style: NocturneText.pageTitle)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(context, 'Estado', _statusLabel(connectionState), dotColor: _statusColor(connectionState)),
                    const Divider(height: 32),
                    _row(context, 'Instância', config?.baseUrl ?? '--'),
                    const Divider(height: 32),
                    _row(context, 'Entidades', '$entityCount'),
                    const Divider(height: 32),
                    ValueListenableBuilder<MqttConnectionStatus>(
                      valueListenable: MqttConnectionController.instance.status,
                      builder: (context, mqttStatus, _) =>
                          _row(context, 'MQTT', _mqttStatusLabel(mqttStatus), dotColor: _mqttStatusColor(mqttStatus)),
                    ),
                    const Divider(height: 32),
                    _row(
                      context,
                      'Música (Mass)',
                      massConfig == null ? 'Não configurado' : _massStatusLabel(massState),
                      dotColor: massConfig == null ? NocturneColors.neutral500 : _massStatusColor(massState),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.fromLTRB(18, 12, 18, 0), child: BrightnessSliderCard()),
        ),
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.fromLTRB(18, 12, 18, 0), child: RebootButtonCard()),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: SettingsNavTile(
              icon: Icons.bolt_outlined,
              title: 'Cartão de Energia',
              subtitle: 'Entidades de rede, solar, bateria, casa e sensores individuais',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EnergySettingsScreen())),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: SettingsNavTile(
              icon: Icons.query_stats_outlined,
              title: 'Página de Energia',
              subtitle: 'Potência instalada, tarifário, inversor, previsão solar e manutenção',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EnergyPageSettingsScreen())),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: SettingsNavTile(
              icon: Icons.grid_view_outlined,
              title: 'Divisões',
              subtitle: 'Divisões mostradas na página Divisões e as suas entidades',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoomsSettingsScreen())),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: SettingsNavTile(
              icon: Icons.thermostat_outlined,
              title: 'Temperaturas',
              subtitle: 'Entidades de temperatura, ar interior e clima exterior',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TemperatureSettingsScreen())),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: SettingsNavTile(
              icon: Icons.event_outlined,
              title: 'Calendário',
              subtitle: 'Calendários mostrados na folha e as suas cores',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarSettingsScreen())),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: SettingsNavTile(
              icon: Icons.electric_car_outlined,
              title: 'Carros elétricos',
              subtitle: 'Nome e entidades de cada um dos 2 cartões de carro',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EvCarsSettingsScreen())),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: SettingsNavTile(
              icon: Icons.speaker_group_outlined,
              title: 'Música',
              subtitle: 'Servidor Music Assistant usado pela folha de Música',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MusicSettingsScreen())),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppNavBar.floatingClearance + MediaQuery.paddingOf(context).bottom + NocturneSpacing.rowGap,
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, {Color? dotColor}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: NocturneText.body)),
        if (dotColor != null) ...[Icon(Icons.circle, size: 12, color: dotColor), const SizedBox(width: 8)],
        Text(value, style: NocturneText.itemTitle),
      ],
    );
  }

  String _statusLabel(HaConnectionState state) => switch (state) {
    HaConnectionState.connected => 'Ligado',
    HaConnectionState.connecting => 'A ligar',
    HaConnectionState.authenticating => 'A autenticar',
    HaConnectionState.error => 'Erro',
    HaConnectionState.disconnected => 'Desligado',
  };

  Color _statusColor(HaConnectionState state) => switch (state) {
    HaConnectionState.connected => NocturneColors.batteryMark,
    HaConnectionState.connecting => NocturneColors.solarMark,
    HaConnectionState.authenticating => NocturneColors.solarMark,
    HaConnectionState.error => NocturneColors.red,
    HaConnectionState.disconnected => NocturneColors.neutral500,
  };

  String _mqttStatusLabel(MqttConnectionStatus status) => switch (status) {
    MqttConnectionStatus.connected => 'Ligado',
    MqttConnectionStatus.connecting => 'A ligar',
    MqttConnectionStatus.error => 'Erro',
    MqttConnectionStatus.disconnected => 'Desligado',
    MqttConnectionStatus.disabled => 'Não configurado',
  };

  Color _mqttStatusColor(MqttConnectionStatus status) => switch (status) {
    MqttConnectionStatus.connected => NocturneColors.batteryMark,
    MqttConnectionStatus.connecting => NocturneColors.solarMark,
    MqttConnectionStatus.error => NocturneColors.red,
    MqttConnectionStatus.disconnected => NocturneColors.neutral500,
    MqttConnectionStatus.disabled => NocturneColors.neutral500,
  };

  String _massStatusLabel(MassConnectionState state) => switch (state) {
    MassConnectionState.connected => 'Ligado',
    MassConnectionState.connecting => 'A ligar',
    MassConnectionState.authenticating => 'A autenticar',
    MassConnectionState.error => 'Erro',
    MassConnectionState.disconnected => 'Desligado',
  };

  Color _massStatusColor(MassConnectionState state) => switch (state) {
    MassConnectionState.connected => NocturneColors.batteryMark,
    MassConnectionState.connecting => NocturneColors.solarMark,
    MassConnectionState.authenticating => NocturneColors.solarMark,
    MassConnectionState.error => NocturneColors.red,
    MassConnectionState.disconnected => NocturneColors.neutral500,
  };
}
