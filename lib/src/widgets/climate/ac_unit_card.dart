import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import '../../providers/rooms_store.dart';
import '../../theme/nocturne_theme.dart';
import 'ac_mode.dart';

/// One AC unit card on the Climatização page — the reference design's
/// "mode block" layout (option 1b): a fixed-width left block (mode/target/
/// steppers) beside a flexible right block (room name, toggle, mode chips).
///
/// Backed by a real `climate.*` entity (see [RoomConfig.climateEntityId]);
/// the 4 mode chips only show the ones the entity's own `hvac_modes`
/// attribute actually supports, so an AC that can't dehumidify, say, never
/// offers a chip that would just fail.
class AcUnitCard extends ConsumerWidget {
  const AcUnitCard({super.key, required this.room, required this.entity});

  final RoomConfig room;
  final HaEntity? entity;

  static const _minTempFallback = 16.0;
  static const _maxTempFallback = 30.0;
  static const _stepFallback = 0.5;

  bool get _unavailable => entity == null || entity!.isUnavailable;

  bool get _on => !_unavailable && entity!.state != 'off';

  double? get _target => entity?.attributes['temperature'] is num ? (entity!.attributes['temperature'] as num).toDouble() : null;

  double? get _current => entity?.attributes['current_temperature'] is num ? (entity!.attributes['current_temperature'] as num).toDouble() : null;

  double get _step => (entity?.attributes['target_temp_step'] as num?)?.toDouble() ?? _stepFallback;

  double get _minTemp => (entity?.attributes['min_temp'] as num?)?.toDouble() ?? _minTempFallback;

  double get _maxTemp => (entity?.attributes['max_temp'] as num?)?.toDouble() ?? _maxTempFallback;

  List<String> get _supportedModes => (entity?.attributes['hvac_modes'] as List?)?.cast<String>() ?? const [];

  Future<void> _toggle(WidgetRef ref) async {
    if (entity == null) return;
    final client = ref.read(haWebSocketClientProvider);
    await client.callService('climate', _on ? 'turn_off' : 'turn_on', target: {'entity_id': entity!.entityId});
  }

  Future<void> _pickMode(WidgetRef ref, String hvacMode) async {
    if (entity == null) return;
    final client = ref.read(haWebSocketClientProvider);
    await client.callService('climate', 'set_hvac_mode', serviceData: {'hvac_mode': hvacMode}, target: {'entity_id': entity!.entityId});
  }

  Future<void> _adjustTarget(WidgetRef ref, double delta) async {
    if (entity == null || _target == null) return;
    final next = (_target! + delta).clamp(_minTemp, _maxTemp);
    final client = ref.read(haWebSocketClientProvider);
    await client.callService('climate', 'set_temperature', serviceData: {'temperature': next}, target: {'entity_id': entity!.entityId});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chip = _on ? acChipFor(entity!.state) : null;
    final onColor = chip?.color;
    final onTint = chip?.tint ?? NocturneColors.neutral600;
    final onSoft = chip?.soft ?? NocturneColors.neutral400;

    return DecoratedBox(
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LeftBlock(
                on: _on,
                unavailable: _unavailable,
                verb: _on ? (chip?.verb ?? 'Ligado') : 'Desligado',
                verbColor: _on ? onSoft : NocturneColors.neutral500,
                target: _target,
                minTemp: _minTemp,
                maxTemp: _maxTemp,
                tint: onTint,
                unitColor: _on ? onSoft : NocturneColors.neutral500,
                onStepDown: () => _adjustTarget(ref, -_step),
                onStepUp: () => _adjustTarget(ref, _step),
              ),
              Expanded(
                child: _RightBlock(
                  name: room.name,
                  nowLabel: _current == null ? '-- agora' : '${_current!.toStringAsFixed(1).replaceAll('.', ',')}° agora',
                  on: _on,
                  unavailable: _unavailable,
                  tint: onTint,
                  color: onColor ?? NocturneColors.neutral600,
                  supportedModes: _supportedModes,
                  currentMode: _on ? entity!.state : null,
                  offHint: _target == null
                      ? 'Toque no interruptor para ligar.'
                      : 'Toque no interruptor para ligar a ${_target!.toStringAsFixed(1).replaceAll('.', ',')}°.',
                  onToggle: _unavailable ? null : () => _toggle(ref),
                  onPickMode: _unavailable ? null : (mode) => _pickMode(ref, mode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeftBlock extends StatelessWidget {
  const _LeftBlock({
    required this.on,
    required this.unavailable,
    required this.verb,
    required this.verbColor,
    required this.target,
    required this.minTemp,
    required this.maxTemp,
    required this.tint,
    required this.unitColor,
    required this.onStepDown,
    required this.onStepUp,
  });

  final bool on;
  final bool unavailable;
  final String verb;
  final Color verbColor;
  final double? target;
  final double minTemp;
  final double maxTemp;
  final Color tint;
  final Color unitColor;
  final VoidCallback onStepDown;
  final VoidCallback onStepUp;

  @override
  Widget build(BuildContext context) {
    final bg = on ? Color.lerp(NocturneColors.surface, tint, 0.3)! : NocturneColors.neutral900;
    final targetColor = on ? NocturneColors.text : NocturneColors.neutral300;

    return Container(
      width: 210,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            verb.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, letterSpacing: 1.4, fontWeight: FontWeight.w500, color: verbColor),
          ),
          // Scales down rather than overflows if a particular climate
          // entity's target ever renders wider than the 166px left block
          // has room for (a 3-decimal step, an unusually large min/max
          // range, ...) — the 210px block width matches the reference
          // design's own 2-digit example values, which won't hold for
          // every real-world `climate.*` entity.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  target == null ? '--' : target!.toStringAsFixed(1).replaceAll('.', ','),
                  style: NocturneText.tabularNums.copyWith(fontSize: 38, fontWeight: FontWeight.w600, letterSpacing: -1.5, color: targetColor, height: 1),
                ),
                const SizedBox(width: 4),
                Text('°C', style: TextStyle(fontSize: 17, color: unitColor)),
              ],
            ),
          ),
          if (on && target != null)
            Row(
              children: [
                _StepButton(icon: Icons.remove, enabled: !unavailable && target! > minTemp, onTap: onStepDown),
                const SizedBox(width: 10),
                _StepButton(icon: Icons.add, enabled: !unavailable && target! < maxTemp, onTap: onStepUp),
              ],
            )
          else
            Text('alvo guardado', style: TextStyle(fontSize: 15, color: NocturneColors.neutral500)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NocturneColors.text.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 54,
          height: 44,
          child: Icon(icon, size: 22, color: enabled ? NocturneColors.text : NocturneColors.neutral500),
        ),
      ),
    );
  }
}

class _RightBlock extends StatelessWidget {
  const _RightBlock({
    required this.name,
    required this.nowLabel,
    required this.on,
    required this.unavailable,
    required this.tint,
    required this.color,
    required this.supportedModes,
    required this.currentMode,
    required this.offHint,
    required this.onToggle,
    required this.onPickMode,
  });

  final String name;
  final String nowLabel;
  final bool on;
  final bool unavailable;
  final Color tint;
  final Color color;
  final List<String> supportedModes;
  final String? currentMode;
  final String offHint;
  final VoidCallback? onToggle;
  final ValueChanged<String>? onPickMode;

  @override
  Widget build(BuildContext context) {
    final chips = supportedModes.isEmpty ? allAcChips : allAcChips.where((c) => supportedModes.contains(c.hvacMode)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500, color: NocturneColors.text)),
                    const SizedBox(height: 4),
                    Text(unavailable ? 'Indisponível' : nowLabel, style: TextStyle(fontSize: 16, color: NocturneColors.neutral500)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AcToggle(on: on, tint: tint, color: color, onTap: onToggle),
            ],
          ),
          if (on)
            Row(
              children: [
                for (final chip in chips) ...[
                  Expanded(child: _ModeChip(chip: chip, active: chip.hvacMode == currentMode, onTap: onPickMode == null ? null : () => onPickMode!(chip.hvacMode))),
                  if (chip != chips.last) const SizedBox(width: 8),
                ],
              ],
            )
          else
            Text(offHint, style: TextStyle(fontSize: 16, color: NocturneColors.neutral500, height: 1.4)),
        ],
      ),
    );
  }
}

class _AcToggle extends StatelessWidget {
  const _AcToggle({required this.on, required this.tint, required this.color, required this.onTap});

  final bool on;
  final Color tint;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pillBg = on ? Color.lerp(NocturneColors.surface, tint, 0.34)! : NocturneColors.neutral900;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: NocturneDurations.colorChange,
        width: 78,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(22)),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: NocturneDurations.colorChange,
          width: 34,
          height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, color: on ? color : NocturneColors.neutral600),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.chip, required this.active, required this.onTap});

  final AcChipSpec chip;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Color.lerp(NocturneColors.surface, chip.tint, 0.26) : NocturneColors.neutral900,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            chip.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: active ? chip.soft : NocturneColors.neutral500),
          ),
        ),
      ),
    );
  }
}
