import 'package:flutter/material.dart';

import '../../../theme/nocturne_theme.dart';

class _PlanoRow {
  const _PlanoRow({required this.icon, required this.title, required this.sub, required this.window, required this.color, this.done = false});

  final IconData icon;
  final String title;
  final String sub;
  final String window;
  final Color color;
  final bool done;
}

/// Illustrative surplus-scheduling suggestions — this app has no automated
/// scheduling logic behind it (that would need a real rules/prediction
/// engine well beyond this dashboard's scope), so unlike every other
/// section on this page these three rows are static sample content, not
/// derived from any entity. Kept because the design reference calls for the
/// section; revisit if/when a real scheduling feature exists to back it.
final _rows = [
  _PlanoRow(
    icon: Icons.local_laundry_service_outlined,
    title: 'Máquina de lavar',
    sub: '1,1 kWh · cabe no excedente de hoje',
    window: '16h – 17h',
    color: NocturneColors.solarMark,
  ),
  _PlanoRow(
    icon: Icons.electric_car_outlined,
    title: 'Model 3 · +60 km',
    sub: '9,4 kWh — hoje já não há sol, sábado prevê 26,1 kWh',
    window: 'amanhã 11h – 16h',
    color: NocturneColors.batteryMark,
  ),
  _PlanoRow(
    icon: Icons.water_drop_outlined,
    title: 'AQS até 55°',
    sub: 'já agendado pela automação solar',
    window: 'feito 13h',
    color: NocturneColors.neutral400,
    done: true,
  ),
];

/// Section 3 of the Energia page: "Plano do excedente".
class EnergyPlanoSection extends StatelessWidget {
  const EnergyPlanoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('PLANO DO EXCEDENTE', style: NocturneText.cardKicker)),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 16, color: NocturneColors.neutral400, decoration: TextDecoration.none),
                  children: [
                    TextSpan(text: 'Sobram '),
                    TextSpan(text: '2,2 kWh', style: TextStyle(color: NocturneColors.solarMark, fontWeight: FontWeight.w600)),
                    TextSpan(text: ' de sol até às 18h'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _PlanoTile(row: _rows[i]),
        ],
      ],
    );
  }
}

class _PlanoTile extends StatelessWidget {
  const _PlanoTile({required this.row});

  final _PlanoRow row;

  @override
  Widget build(BuildContext context) {
    final bg = row.done ? NocturneColors.neutral900 : Color.alphaBlend(row.color.withValues(alpha: 0.18), NocturneColors.surface);
    final chipBg = row.done ? NocturneColors.neutral900 : Color.alphaBlend(row.color.withValues(alpha: 0.16), NocturneColors.surface);
    final chipColor = row.done ? NocturneColors.neutral400 : row.color;

    return Opacity(
      opacity: row.done ? 0.7 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.roomCard)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NocturneRadii.chip)),
              child: Icon(row.icon, size: 24, color: row.done ? NocturneColors.neutral400 : row.color),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(row.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(row.sub, style: TextStyle(fontSize: 15, color: NocturneColors.neutral500)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(NocturneRadii.pill)),
              child: Text(row.window, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: chipColor)),
            ),
          ],
        ),
      ),
    );
  }
}
