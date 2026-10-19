import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/house_models.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/ac_widgets.dart';
import '../widgets/kiosk_widgets.dart';

Future<void> showClimateModal(BuildContext context) => showKModal(context, (_) => const ClimateModal());

/// Every AC unit with its own controls (the design's "Modal ar
/// condicionado"), opened from Início's "Ver todos".
class ClimateModal extends ConsumerWidget {
  const ClimateModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(acUnitsProvider);
    final outside = ref.watch(weatherNowProvider).temp;
    final on = units.where((u) => u.on).length;
    final summary = [on == 0 ? 'Todos desligados' : '$on de ${units.length} ligados', if (outside != null) 'Exterior ${outside.round()}°'].join(' · ');
    return KModal(
      background: KColors.sub,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: KModalHeader(
              title: 'Ar condicionado',
              subtitle: summary,
              closeBg: Colors.white,
              trailing: on == 0
                  ? null
                  : KButton(
                      label: 'Desligar todos',
                      icon: KIcons.power,
                      iconSize: 22,
                      height: 60,
                      fontSize: 19,
                      border: null,
                      gap: 8,
                      padding: const EdgeInsets.fromLTRB(16, 0, 22, 0),
                      onTap: () => ref.read(acActionsProvider).allOff(units).catchError(KToast.error),
                    ),
            ),
          ),
          if (units.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Nenhum ar condicionado configurado.', style: KText.s(20, color: KColors.muted)),
            ),
          for (final u in units) ...[KAcRow(unit: u), const SizedBox(height: 16)],
        ],
      ),
    );
  }
}
