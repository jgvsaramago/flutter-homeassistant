import 'package:flutter/material.dart';

import '../models/ha_entity.dart';

/// Maps an entity to a reasonable Material icon based on its domain, device
/// class and current state. Not exhaustive — falls back to a generic dot.
IconData iconForEntity(HaEntity entity) {
  switch (entity.domain) {
    case 'light':
      return entity.isOn ? Icons.lightbulb : Icons.lightbulb_outline;
    case 'switch':
      return entity.isOn ? Icons.toggle_on : Icons.toggle_off;
    case 'binary_sensor':
      return _binarySensorIcon(entity);
    case 'sensor':
      return _sensorIcon(entity);
    case 'climate':
      return Icons.thermostat;
    case 'cover':
      return entity.state == 'open' ? Icons.garage_outlined : Icons.garage;
    case 'lock':
      return entity.state == 'locked' ? Icons.lock : Icons.lock_open;
    case 'fan':
      return Icons.mode_fan_off;
    case 'media_player':
      return Icons.speaker;
    case 'camera':
      return Icons.videocam;
    case 'person':
      return Icons.person;
    case 'weather':
      return Icons.cloud_outlined;
    case 'automation':
      return Icons.bolt;
    case 'scene':
      return Icons.theater_comedy_outlined;
    case 'script':
      return Icons.play_circle_outline;
    default:
      return Icons.radio_button_checked;
  }
}

IconData _binarySensorIcon(HaEntity entity) {
  switch (entity.deviceClass) {
    case 'motion':
      return entity.isOn ? Icons.directions_run : Icons.no_accounts;
    case 'door':
    case 'garage_door':
      return entity.isOn ? Icons.meeting_room : Icons.door_front_door;
    case 'window':
      return Icons.window;
    case 'smoke':
      return Icons.smoke_free;
    case 'moisture':
      return Icons.water_drop_outlined;
    default:
      return entity.isOn ? Icons.check_circle_outline : Icons.circle_outlined;
  }
}

IconData _sensorIcon(HaEntity entity) {
  switch (entity.deviceClass) {
    case 'temperature':
      return Icons.thermostat_outlined;
    case 'humidity':
      return Icons.water_drop_outlined;
    case 'battery':
      return Icons.battery_std;
    case 'power':
    case 'energy':
      return Icons.bolt_outlined;
    case 'illuminance':
      return Icons.wb_sunny_outlined;
    case 'pressure':
      return Icons.speed_outlined;
    default:
      return Icons.analytics_outlined;
  }
}

const _domainLabels = {
  'light': 'Lights',
  'switch': 'Switches',
  'binary_sensor': 'Binary Sensors',
  'sensor': 'Sensors',
  'climate': 'Climate',
  'cover': 'Covers',
  'lock': 'Locks',
  'fan': 'Fans',
  'media_player': 'Media Players',
  'camera': 'Cameras',
  'person': 'People',
  'weather': 'Weather',
  'automation': 'Automations',
  'scene': 'Scenes',
  'script': 'Scripts',
};

/// Human-friendly label for a domain, used as a section header.
String labelForDomain(String domain) {
  final known = _domainLabels[domain];
  if (known != null) return known;
  final words = domain.split('_');
  return words.map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}
