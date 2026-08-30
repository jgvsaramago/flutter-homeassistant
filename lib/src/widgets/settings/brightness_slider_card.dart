import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/screen_brightness_service.dart';
import '../../theme/nocturne_theme.dart';

const _writeDebounce = Duration(milliseconds: 150);

/// Slider controlling the device's screen backlight (the Pi's DSI
/// touchscreen). Renders nothing on platforms/devices with no backlight to
/// control (web preview, desktop dev machines, a Pi with no detected
/// backlight device).
class BrightnessSliderCard extends StatefulWidget {
  const BrightnessSliderCard({super.key});

  @override
  State<BrightnessSliderCard> createState() => _BrightnessSliderCardState();
}

class _BrightnessSliderCardState extends State<BrightnessSliderCard> {
  static const _service = ScreenBrightnessService();

  double? _percent;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (_service.isSupported) _load();
  }

  Future<void> _load() async {
    final value = await _service.readPercent();
    if (mounted) setState(() => _percent = (value ?? 100).toDouble());
  }

  void _onChanged(double value) {
    setState(() {
      _percent = value;
      _error = null;
    });
    _debounce?.cancel();
    _debounce = Timer(_writeDebounce, () async {
      final ok = await _service.setPercent(value.round());
      if (!ok && mounted) setState(() => _error = 'Não foi possível alterar o brilho (sem permissões?)');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final percent = _percent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.brightness_6_outlined, color: theme.colorScheme.primary, size: 26),
                const SizedBox(width: 10),
                const Text('Brilho do ecrã', style: NocturneText.itemTitle),
                const Spacer(),
                Text(percent == null ? '--' : '${percent.round()}%', style: NocturneText.itemTitle),
              ],
            ),
            Slider(value: percent ?? 100, min: 0, max: 100, onChanged: percent == null ? null : _onChanged),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 15)),
              ),
          ],
        ),
      ),
    );
  }
}
