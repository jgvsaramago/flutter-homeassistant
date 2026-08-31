import 'package:flutter/material.dart';

import '../../services/system_control_service.dart';
import '../../theme/nocturne_theme.dart';

/// A one-shot control that reboots the physical device — same
/// `SystemControlService.reboot()` (`sudo reboot`, needs the passwordless
/// sudoers rule documented on that class) already wired to Home Assistant's
/// MQTT "Reboot" button, just triggered locally instead of over the
/// network. Renders nothing on platforms with nothing to reboot (web
/// preview, desktop dev machines), same gating `BrightnessSliderCard` uses.
class RebootButtonCard extends StatefulWidget {
  const RebootButtonCard({super.key});

  @override
  State<RebootButtonCard> createState() => _RebootButtonCardState();
}

class _RebootButtonCardState extends State<RebootButtonCard> {
  static final _service = SystemControlService();

  bool _rebooting = false;
  String? _error;

  Future<void> _onTap() async {
    final confirmed = await _confirmReboot(context);
    if (confirmed != true || !mounted) return;

    setState(() {
      _rebooting = true;
      _error = null;
    });
    final ok = await _service.reboot();
    // A successful reboot kills this process within a second or two — if
    // we're still here to run this, either it failed outright or the
    // shutdown is slow enough that showing the error (were it to stay
    // false) is still worth doing rather than leaving the button stuck
    // spinning forever.
    if (!mounted) return;
    setState(() {
      _rebooting = ok;
      if (!ok) _error = 'Não foi possível reiniciar (sem permissões?)';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restart_alt, color: theme.colorScheme.primary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Reiniciar o Raspberry Pi', style: NocturneText.itemTitle),
                      SizedBox(height: 4),
                      Text('O ecrã fica indisponível durante cerca de um minuto.', style: NocturneText.body),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _rebooting ? null : _onTap,
                  child: _rebooting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Reiniciar'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 15)),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmReboot(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: NocturneColors.scrim,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.primaryCard)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reiniciar o Raspberry Pi?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(
              'O dashboard fica indisponível durante o reinício.',
              style: TextStyle(fontSize: 16, color: NocturneColors.neutral400, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reiniciar')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
