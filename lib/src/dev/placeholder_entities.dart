import 'dart:math' as math;

import '../providers/energy_entities_store.dart';
import '../ha_client/ha_connection_config.dart';
import '../models/ha_entity.dart';
import '../providers/energy_entities_provider.dart';
import '../providers/energy_page_settings_provider.dart';
import '../providers/energy_page_settings_store.dart';
import '../providers/ev_cars_provider.dart';
import '../providers/ev_cars_store.dart';
import '../providers/ha_providers.dart';
import '../providers/individual_sensors_provider.dart';
import '../providers/individual_sensors_store.dart';
import '../providers/rooms_provider.dart';
import '../providers/rooms_store.dart';

/// Canned entity set used in place of a real websocket connection — see
/// [placeholderEntitiesProvider] in `main.dart`. Covers the domains the UI
/// groups by ([labelForDomain]) plus the two fixed sensor ids the dashboard
/// header reads directly.
Map<String, HaEntity> buildPlaceholderEntities() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  HaEntity entity(String id, String state, [Map<String, dynamic> attrs = const {}]) {
    return HaEntity(entityId: id, state: state, attributes: attrs, lastChanged: now, lastUpdated: now);
  }

  // A rough bell curve so the Energia page's "previsto" production bars (see
  // `EnergyForecastData.hourlyExpectedKwh`) have some shape in the preview
  // instead of a flat line — half-hourly, matching the real Solcast
  // integration's `detailedForecast` attribute shape.
  final detailedForecast = <Map<String, dynamic>>[
    for (var h = 6; h <= 19; h++)
      for (final minute in [0, 30])
        {
          'period_start': today.add(Duration(hours: h, minutes: minute)).toIso8601String(),
          'pv_estimate': 1.8 * math.exp(-math.pow(h + minute / 60.0 - 13, 2) / 18),
        },
  ];

  // Mirrors the Energia page build spec's own 7-day forecast example
  // dataset (kWh) and a plausible matching condition/temperature per day,
  // so the demo preview's forecast section shows the same shape the design
  // reference does.
  const forecastKwh = [29.6, 26.1, 21.5, 12.8, 18.9, 27.0, 29.2];
  const forecastCondition = ['sunny', 'sunny', 'partlycloudy', 'rainy', 'partlycloudy', 'sunny', 'sunny'];
  const forecastTempMax = [31, 30, 27, 22, 25, 29, 32];
  final weatherForecast = [
    for (var i = 0; i < 7; i++)
      {'datetime': today.add(Duration(days: i)).toIso8601String(), 'condition': forecastCondition[i], 'temperature': forecastTempMax[i]},
  ];

  return {
    for (final e in [
      entity('light.kitchen', 'on', {'friendly_name': 'Kitchen Light'}),
      entity('light.living_room', 'off', {'friendly_name': 'Living Room Light'}),
      entity('light.bedroom', 'on', {'friendly_name': 'Bedroom Light'}),
      entity('switch.coffee_machine', 'off', {'friendly_name': 'Coffee Machine'}),
      entity('switch.garden_sprinkler', 'on', {'friendly_name': 'Garden Sprinkler'}),
      entity('sensor.sotao_gw2000a_wifiee57_outdoor_temperature', '21.4', {
        'friendly_name': 'Outdoor Temperature',
        'unit_of_measurement': '°C',
        'device_class': 'temperature',
      }),
      entity('sensor.temperatura_media_casa_piso_0', '23.1', {
        'friendly_name': 'Floor 0 Temperature',
        'unit_of_measurement': '°C',
        'device_class': 'temperature',
      }),
      entity('sensor.living_room_humidity', '48', {
        'friendly_name': 'Living Room Humidity',
        'unit_of_measurement': '%',
        'device_class': 'humidity',
      }),
      entity('binary_sensor.front_door', 'off', {'friendly_name': 'Front Door', 'device_class': 'door'}),
      entity('binary_sensor.hallway_motion', 'on', {'friendly_name': 'Hallway Motion', 'device_class': 'motion'}),
      entity('binary_sensor.living_room_window', 'on', {'friendly_name': 'Living Room Window', 'device_class': 'window'}),
      entity('climate.living_room', 'heat', {'friendly_name': 'Living Room Thermostat', 'temperature': 21.0}),
      entity('cover.garage_door', 'closed', {'friendly_name': 'Garage Door', 'device_class': 'garage'}),
      entity('lock.front_door', 'locked', {'friendly_name': 'Front Door Lock'}),
      entity('media_player.living_room_speaker', 'playing', {'friendly_name': 'Living Room Speaker'}),
      entity('persistent_notification.update_available', 'notifying', {'friendly_name': 'Update available'}),
      // Matches the energy card build spec's own example scenario (grid
      // importing 1.1kW, solar 3.1kW, battery discharging 0.8kW at 72%,
      // home drawing 1.2kW) so the demo preview actually shows it live
      // rather than every energy node reading "--".
      entity('sensor.demo_grid_power', '1100', {'friendly_name': 'Demo Grid Power', 'unit_of_measurement': 'W'}),
      entity('sensor.demo_solar_power', '3100', {'friendly_name': 'Demo Solar Power', 'unit_of_measurement': 'W'}),
      entity('sensor.demo_battery_power', '800', {'friendly_name': 'Demo Battery Power', 'unit_of_measurement': 'W'}),
      entity('sensor.demo_battery_soc', '72', {'friendly_name': 'Demo Battery SOC', 'unit_of_measurement': '%'}),
      entity('sensor.demo_home_power', '1200', {'friendly_name': 'Demo Home Power', 'unit_of_measurement': 'W'}),
      entity('sensor.demo_car_left_battery', '82', {'friendly_name': 'Demo Left Car Battery', 'unit_of_measurement': '%'}),
      entity('sensor.demo_car_left_range', '268', {'friendly_name': 'Demo Left Car Range', 'unit_of_measurement': 'km'}),
      entity('binary_sensor.demo_car_left_charging', 'on', {'friendly_name': 'Demo Left Car Charging'}),
      entity('sensor.demo_car_right_battery', '54', {'friendly_name': 'Demo Right Car Battery', 'unit_of_measurement': '%'}),
      entity('sensor.demo_car_right_range', '178', {'friendly_name': 'Demo Right Car Range', 'unit_of_measurement': 'km'}),
      entity('binary_sensor.demo_car_right_charging', 'off', {'friendly_name': 'Demo Right Car Charging'}),
      // Plugged in but not drawing current — exercises the "Ligado, sem
      // carregar" state distinct from both "A carregar" and unplugged.
      entity('binary_sensor.demo_car_right_plug', 'on', {'friendly_name': 'Demo Right Car Plug'}),
      // Matches the energy card build spec's own example device readings
      // (AQS 49ºC/0.6kW, Frigorífico 0.15kW, TV 0.1kW, Máquina de lavar
      // 0.3kW) so the demo preview shows the card's 4 device slots live.
      entity('sensor.demo_aqs_power', '600', {'friendly_name': 'Demo AQS Power', 'unit_of_measurement': 'W'}),
      entity('sensor.demo_aqs_temperature', '49', {'friendly_name': 'Demo AQS Temperature', 'unit_of_measurement': '°C', 'device_class': 'temperature'}),
      entity('sensor.demo_fridge_power', '150', {'friendly_name': 'Demo Fridge Power', 'unit_of_measurement': 'W'}),
      entity('sensor.demo_tv_power', '100', {'friendly_name': 'Demo TV Power', 'unit_of_measurement': 'W'}),
      entity('sensor.demo_washer_power', '300', {'friendly_name': 'Demo Washer Power', 'unit_of_measurement': 'W'}),
      // Energia page (full-screen tab) demo entities — inverter health,
      // 7-day Solcast-style forecast (today's also carries a detailed
      // half-hourly attribute for the production chart's "previsto" bars),
      // and a weather entity for that forecast's condition/temperature.
      entity('sensor.demo_inverter_status', 'on', {'friendly_name': 'Demo Inverter Status'}),
      entity('sensor.demo_inverter_temperature', '42', {'friendly_name': 'Demo Inverter Temperature', 'unit_of_measurement': '°C'}),
      entity('sensor.demo_inverter_efficiency', '98.1', {'friendly_name': 'Demo Inverter Efficiency', 'unit_of_measurement': '%'}),
      entity('sensor.demo_solcast_day0', forecastKwh[0].toString(), {'friendly_name': 'Demo Solcast Today', 'detailedForecast': detailedForecast}),
      for (var i = 1; i < 7; i++) entity('sensor.demo_solcast_day$i', forecastKwh[i].toString(), {'friendly_name': 'Demo Solcast D+$i'}),
      entity('weather.demo_casa', 'sunny', {'friendly_name': 'Demo Weather', 'forecast': weatherForecast}),
      // Six rooms covering the Divisões page's full variety: a lit room
      // with music playing, an open window, active A/C with a CO₂ reading,
      // a closed-up kitchen, a locked entryway, and a bare idle attic.
      entity('light.demo_room_sala', 'on', {'friendly_name': 'Luz da Sala'}),
      entity('sensor.demo_room_sala_temp', '21.5', {'friendly_name': 'Sala Temperature', 'unit_of_measurement': '°C', 'device_class': 'temperature'}),
      entity('sensor.demo_room_sala_humidity', '47', {'friendly_name': 'Sala Humidity', 'unit_of_measurement': '%', 'device_class': 'humidity'}),
      entity('cover.demo_room_sala', 'open', {'friendly_name': 'Estores da Sala', 'current_position': 40}),
      entity('media_player.demo_room_sala', 'playing', {'friendly_name': 'Altifalante da Sala'}),
      entity('binary_sensor.demo_room_quarto_window', 'on', {'friendly_name': 'Janela do Quarto', 'device_class': 'window'}),
      entity('sensor.demo_room_quarto_temp', '20.1', {'friendly_name': 'Quarto Temperature', 'unit_of_measurement': '°C', 'device_class': 'temperature'}),
      entity('cover.demo_room_quarto', 'open', {'friendly_name': 'Estores do Quarto', 'current_position': 70}),
      entity('media_player.demo_room_quarto', 'idle', {'friendly_name': 'Altifalante do Quarto'}),
      entity('climate.demo_room_escritorio', 'heat', {'friendly_name': 'AC do Escritório'}),
      entity('sensor.demo_room_escritorio_temp', '20.9', {'friendly_name': 'Escritório Temperature', 'unit_of_measurement': '°C', 'device_class': 'temperature'}),
      entity('sensor.demo_room_escritorio_co2', '612', {'friendly_name': 'Escritório CO2', 'unit_of_measurement': 'ppm', 'device_class': 'carbon_dioxide'}),
      entity('media_player.demo_room_escritorio', 'playing', {'friendly_name': 'Altifalante do Escritório'}),
      entity('light.demo_room_cozinha', 'on', {'friendly_name': 'Luz da Cozinha'}),
      entity('sensor.demo_room_cozinha_temp', '22.8', {'friendly_name': 'Cozinha Temperature', 'unit_of_measurement': '°C', 'device_class': 'temperature'}),
      entity('sensor.demo_room_cozinha_humidity', '52', {'friendly_name': 'Cozinha Humidity', 'unit_of_measurement': '%', 'device_class': 'humidity'}),
      entity('cover.demo_room_cozinha', 'closed', {'friendly_name': 'Estores da Cozinha'}),
      entity('lock.demo_room_entrada', 'locked', {'friendly_name': 'Fechadura da Entrada'}),
      entity('sensor.demo_room_entrada_temp', '21.0', {'friendly_name': 'Entrada Temperature', 'unit_of_measurement': '°C', 'device_class': 'temperature'}),
      entity('sensor.demo_room_sotao_temp', '24.6', {'friendly_name': 'Sótão Temperature', 'unit_of_measurement': '°C', 'device_class': 'temperature'}),
    ])
      e.entityId: e,
  };
}

/// Drop-in replacement for [EntitiesNotifier] that never touches the
/// websocket client — returns the same canned snapshot immediately.
class PlaceholderEntitiesNotifier extends EntitiesNotifier {
  @override
  Future<Map<String, HaEntity>> build() async => buildPlaceholderEntities();
}

/// Provider overrides that swap in placeholder data instead of a real HA
/// connection. Apply via `ProviderScope(overrides: placeholderOverrides)`.
final placeholderOverrides = [
  entitiesProvider.overrideWith(PlaceholderEntitiesNotifier.new),
  areaByEntityIdProvider.overrideWith((ref) async => const {}),
  connectionConfigProvider.overrideWith(
    (ref) => const HaConnectionConfig(baseUrl: 'http://placeholder.invalid', accessToken: 'placeholder'),
  ),
  energyEntityConfigProvider.overrideWith(
    (ref) => const EnergyEntityConfig(
      gridPowerEntityId: 'sensor.demo_grid_power',
      solarPowerEntityId: 'sensor.demo_solar_power',
      batteryPowerEntityId: 'sensor.demo_battery_power',
      batterySocEntityId: 'sensor.demo_battery_soc',
      homePowerEntityId: 'sensor.demo_home_power',
    ),
  ),
  energyPageConfigProvider.overrideWith(
    (ref) => EnergyPageConfig(
      installedKwp: 4.8,
      panelCount: 12,
      panelOrientation: 'sul 30°',
      importPricePerKwh: 0.18,
      exportPricePerKwh: 0.07,
      inverterStatusEntityId: 'sensor.demo_inverter_status',
      inverterTemperatureEntityId: 'sensor.demo_inverter_temperature',
      inverterEfficiencyEntityId: 'sensor.demo_inverter_efficiency',
      weatherEntityId: 'weather.demo_casa',
      lastCleaningDate: DateTime.now().subtract(const Duration(days: 78)),
      nextCleaningDate: DateTime.now().add(const Duration(days: 14)),
      forecastDayEntityIds: [for (var i = 0; i < 7; i++) 'sensor.demo_solcast_day$i'],
    ),
  ),
  evCarsConfigProvider.overrideWith(
    (ref) => const EvCarsConfig(
      left: EvCarConfig(
        name: 'Renault Mégane E-Tech',
        batterySocEntityId: 'sensor.demo_car_left_battery',
        rangeEntityId: 'sensor.demo_car_left_range',
        chargingEntityId: 'binary_sensor.demo_car_left_charging',
        // A public placeholder image, just to exercise the photoUrl ->
        // Image.network path in the browser preview — never reachable from
        // the real kiosk, since demo mode only ever runs there. `.png` is
        // required: placehold.co defaults to SVG, which Image.network can't
        // decode (no flutter_svg in this app).
        photoUrl:
            'https://placehold.co/300x170/1a1b1f/8a8c93.png?text=M%C3%A9gane',
      ),
      right: EvCarConfig(
        name: 'Tesla Model Y',
        batterySocEntityId: 'sensor.demo_car_right_battery',
        rangeEntityId: 'sensor.demo_car_right_range',
        chargingEntityId: 'binary_sensor.demo_car_right_charging',
        plugConnectedEntityId: 'binary_sensor.demo_car_right_plug',
        photoUrl: 'https://placehold.co/300x170/1a1b1f/8a8c93.png?text=Model+Y',
      ),
    ),
  ),
  individualSensorsProvider.overrideWith(
    (ref) => const [
      IndividualSensorConfig(name: 'AQS', powerEntityId: 'sensor.demo_aqs_power', temperatureEntityId: 'sensor.demo_aqs_temperature', icon: IndividualSensorIconKey.boiler),
      IndividualSensorConfig(name: 'Frigorífico', powerEntityId: 'sensor.demo_fridge_power', icon: IndividualSensorIconKey.fridge),
      IndividualSensorConfig(name: 'TV', powerEntityId: 'sensor.demo_tv_power', icon: IndividualSensorIconKey.tv),
      IndividualSensorConfig(name: 'Máquina de lavar', powerEntityId: 'sensor.demo_washer_power', icon: IndividualSensorIconKey.washer),
    ],
  ),
  roomsProvider.overrideWith(
    (ref) => const [
      RoomConfig(
        name: 'Sala',
        temperatureEntityId: 'sensor.demo_room_sala_temp',
        secondaryEntityId: 'sensor.demo_room_sala_humidity',
        lightEntityId: 'light.demo_room_sala',
        coverEntityId: 'cover.demo_room_sala',
        speakerEntityId: 'media_player.demo_room_sala',
      ),
      RoomConfig(
        name: 'Quarto Principal',
        temperatureEntityId: 'sensor.demo_room_quarto_temp',
        windowEntityId: 'binary_sensor.demo_room_quarto_window',
        coverEntityId: 'cover.demo_room_quarto',
        speakerEntityId: 'media_player.demo_room_quarto',
      ),
      RoomConfig(
        name: 'Escritório',
        temperatureEntityId: 'sensor.demo_room_escritorio_temp',
        secondaryEntityId: 'sensor.demo_room_escritorio_co2',
        climateEntityId: 'climate.demo_room_escritorio',
        speakerEntityId: 'media_player.demo_room_escritorio',
      ),
      RoomConfig(
        name: 'Cozinha',
        temperatureEntityId: 'sensor.demo_room_cozinha_temp',
        secondaryEntityId: 'sensor.demo_room_cozinha_humidity',
        lightEntityId: 'light.demo_room_cozinha',
        coverEntityId: 'cover.demo_room_cozinha',
      ),
      RoomConfig(
        name: 'Entrada',
        temperatureEntityId: 'sensor.demo_room_entrada_temp',
        secondaryEntityId: 'lock.demo_room_entrada',
      ),
      RoomConfig(name: 'Sótão', temperatureEntityId: 'sensor.demo_room_sotao_temp'),
    ],
  ),
];
