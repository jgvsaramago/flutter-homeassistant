import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';

/// Shows the volume modal: a centered sheet with a rotated slider, a large
/// percent readout, and step buttons. [initialVolume] seeds the dialog's own
/// state, and every change is also reported via [onChanged] so the caller
/// (the media card) keeps the value once the dialog closes.
Future<void> showVolumeModal(BuildContext context, {required int initialVolume, required ValueChanged<int> onChanged}) {
  return showDialog<void>(
    context: context,
    barrierColor: NocturneColors.scrim,
    builder: (context) => _VolumeDialog(initialVolume: initialVolume, onChanged: onChanged),
  );
}

class _VolumeDialog extends StatefulWidget {
  const _VolumeDialog({required this.initialVolume, required this.onChanged});

  final int initialVolume;
  final ValueChanged<int> onChanged;

  @override
  State<_VolumeDialog> createState() => _VolumeDialogState();
}

class _VolumeDialogState extends State<_VolumeDialog> {
  late int _volume = widget.initialVolume;

  void _set(int value) {
    setState(() => _volume = value.clamp(0, 100));
    widget.onChanged(_volume);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.primaryCard)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Volume', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SizedBox(
                    width: 220,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: NocturneColors.accent,
                        thumbColor: NocturneColors.accent,
                        inactiveTrackColor: NocturneColors.neutral800,
                      ),
                      child: Slider(
                        value: _volume.toDouble(),
                        min: 0,
                        max: 100,
                        onChanged: (v) => _set(v.round()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('$_volume%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepButton(icon: Icons.remove, onTap: () => _set(_volume - 5)),
                const SizedBox(width: 20),
                _StepButton(icon: Icons.add, onTap: () => _set(_volume + 5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NocturneColors.neutral800,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 26, color: NocturneColors.text)),
      ),
    );
  }
}
