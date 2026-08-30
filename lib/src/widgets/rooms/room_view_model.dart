import 'package:flutter/material.dart';

import '../../models/ha_entity.dart';
import '../../providers/rooms_store.dart';
import '../../theme/nocturne_theme.dart';

/// Everything one room card renders, pre-resolved from real entity state —
/// widgets read this, never entity maps or colour rules directly, so the
/// resolution logic lives in exactly one place. Mirrors the reference
/// design's `roomVals()` per-room mapping, adapted from that reference's
/// hand-authored demo data to real HA entities (see [buildRoomView]'s own
/// doc for what changed and why).
class RoomView {
  const RoomView({
    required this.config,
    required this.tempText,
    required this.subText,
    required this.dotColor,
    required this.lightOn,
    required this.windowOpen,
    required this.acOn,
    required this.lightIconColor,
    required this.windowIconColor,
    required this.blindsIconColor,
    required this.acIconColor,
    required this.speakerIconColor,
    required this.hasLight,
    required this.hasWindow,
    required this.hasBlinds,
    required this.hasAc,
    required this.hasSpeaker,
  });

  final RoomConfig config;
  final String tempText;
  final String? subText;
  final Color dotColor;
  final bool lightOn;
  final bool windowOpen;
  final bool acOn;
  final Color lightIconColor;
  final Color windowIconColor;
  final Color blindsIconColor;
  final Color acIconColor;
  final Color speakerIconColor;

  /// Whether each icon has a configured entity at all — a room with no
  /// light wired up shouldn't show a permanently-dim light icon, so the
  /// card only renders icons for capabilities the room actually has.
  final bool hasLight;
  final bool hasWindow;
  final bool hasBlinds;
  final bool hasAc;
  final bool hasSpeaker;
}

bool _hasId(String? id) => id != null && id.trim().isNotEmpty;

HaEntity? _lookup(Map<String, HaEntity> entities, String? id) => _hasId(id) ? entities[id] : null;

double? _numeric(HaEntity? entity) {
  if (entity == null || entity.isUnavailable) return null;
  return double.tryParse(entity.state);
}

/// pt-PT decimal comma, one decimal place — `"--"` when unavailable.
String formatTempComma(double? value) => value == null ? '--' : value.toStringAsFixed(1).replaceAll('.', ',');

bool _isLightOn(Map<String, HaEntity> entities, String? id) {
  final entity = _lookup(entities, id);
  return entity != null && !entity.isUnavailable && entity.isOn;
}

/// HA's own convention for a door/window `binary_sensor`: `on` means open.
bool _isWindowOpen(Map<String, HaEntity> entities, String? id) {
  final entity = _lookup(entities, id);
  return entity != null && !entity.isUnavailable && entity.isOn;
}

/// `climate.*` counts as active whenever it isn't explicitly `off`
/// (heating/cooling/auto/fan/dry all count); anything else (a plain
/// `switch.*` wired to an A/C unit) falls back to on/off.
bool _isAcOn(Map<String, HaEntity> entities, String? id) {
  final entity = _lookup(entities, id);
  if (entity == null || entity.isUnavailable) return false;
  return entity.domain == 'climate' ? entity.state != 'off' : entity.isOn;
}

Color _litOrOff(bool configured, bool active, Color litColor) => configured && active ? litColor : NocturneColors.neutral700;

Color _speakerIconColor(Map<String, HaEntity> entities, String? id) {
  final entity = _lookup(entities, id);
  if (entity == null || entity.isUnavailable) return NocturneColors.neutral700;
  return entity.state == 'playing' ? NocturneColors.accent : NocturneColors.neutral600;
}

/// Blinds read from a real `cover.*` state rather than the reference's own
/// local 0–100 "closing progress" — `closed` reads as at-rest (dimmer),
/// anything else (`open`/`opening`/`closing`) reads as engaged (blue).
Color _blindsIconColor(Map<String, HaEntity> entities, String? id) {
  final entity = _lookup(entities, id);
  if (entity == null || entity.isUnavailable) return NocturneColors.neutral700;
  return entity.state == 'closed' ? NocturneColors.neutral600 : NocturneColors.blue;
}

/// The status dot's colour — the reference hand-authors this per room
/// (sometimes from a temperature threshold, sometimes "a dryer is running
/// is worth celebrating"), which has no single generalizable rule. This
/// picks the clearest generic substitute: an open window is the most
/// actionable state (info), a light left on is next most likely worth a
/// glance (warn), active A/C reads as "comfort being maintained" (good),
/// and a room with nothing configured/active is idle.
Color _dotColor({required bool windowOpen, required bool lightOn, required bool acOn}) {
  if (windowOpen) return NocturneColors.blue;
  if (lightOn) return NocturneColors.amber;
  if (acOn) return NocturneColors.green;
  return NocturneColors.neutral800;
}

/// The card's status line. [RoomConfig.secondaryEntityId] is interpreted by
/// domain/device class so one field covers the reference's variety
/// (humidity %, CO₂ ppm, lock state, or any other sensor's raw reading);
/// unset falls back to the blinds' own position, then omits the line
/// entirely rather than guess at a phrase like the reference's per-room
/// hand-written copy ("Secador · 40 min") that has no generic equivalent.
String? _subText(Map<String, HaEntity> entities, RoomConfig room) {
  final secondary = _lookup(entities, room.secondaryEntityId);
  if (secondary != null && !secondary.isUnavailable) {
    if (secondary.domain == 'lock') {
      return secondary.state == 'locked' ? 'Porta trancada' : 'Porta destrancada';
    }
    if (secondary.deviceClass == 'humidity') {
      final value = double.tryParse(secondary.state);
      return value == null ? secondary.displayState : '${value.round()}% humidade';
    }
    if (secondary.deviceClass == 'carbon_dioxide' || secondary.unitOfMeasurement == 'ppm') {
      final value = double.tryParse(secondary.state);
      return value == null ? secondary.displayState : 'CO₂ ${value.round()} ppm';
    }
    return secondary.displayState;
  }

  final cover = _lookup(entities, room.coverEntityId);
  if (cover != null && !cover.isUnavailable) {
    final position = cover.attributes['current_position'];
    if (position is num) return 'Estores ${position.round()}%';
    return cover.state == 'closed' ? 'Estores fechados' : 'Estores abertos';
  }

  return null;
}

/// Resolves one [RoomConfig] against live entity state into everything its
/// card needs to paint — the one place that logic lives, so the widget
/// tree stays a pure render of this, never re-deriving colours inline.
RoomView buildRoomView(RoomConfig config, Map<String, HaEntity> entities) {
  final lightOn = _isLightOn(entities, config.lightEntityId);
  final windowOpen = _isWindowOpen(entities, config.windowEntityId);
  final acOn = _isAcOn(entities, config.climateEntityId);

  return RoomView(
    config: config,
    tempText: formatTempComma(_numeric(_lookup(entities, config.temperatureEntityId))),
    subText: _subText(entities, config),
    dotColor: _dotColor(windowOpen: windowOpen, lightOn: lightOn, acOn: acOn),
    lightOn: lightOn,
    windowOpen: windowOpen,
    acOn: acOn,
    lightIconColor: _litOrOff(_hasId(config.lightEntityId), lightOn, NocturneColors.amber),
    windowIconColor: _litOrOff(_hasId(config.windowEntityId), windowOpen, NocturneColors.blue),
    blindsIconColor: _blindsIconColor(entities, config.coverEntityId),
    acIconColor: _litOrOff(_hasId(config.climateEntityId), acOn, NocturneColors.green),
    speakerIconColor: _speakerIconColor(entities, config.speakerEntityId),
    hasLight: _hasId(config.lightEntityId),
    hasWindow: _hasId(config.windowEntityId),
    hasBlinds: _hasId(config.coverEntityId),
    hasAc: _hasId(config.climateEntityId),
    hasSpeaker: _hasId(config.speakerEntityId),
  );
}
