import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';

const _weekdayNamesPt = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];
const _monthNamesPt = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Section 1 of the Homepage: greeting + live clock. Ticks every 15 seconds
/// (matching the design reference) since only hours:minutes are shown.
class DashboardHeader extends StatefulWidget {
  const DashboardHeader({super.key});

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = _now.hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String get _dateStr {
    final weekday = _weekdayNamesPt[_now.weekday - 1];
    final month = _monthNamesPt[_now.month - 1];
    return '$weekday, ${_now.day} de $month';
  }

  @override
  Widget build(BuildContext context) {
    final time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return SizedBox(
      height: 148,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, height: 1.15),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aqui está o que se passa em casa',
                  style: TextStyle(fontSize: 20, color: NocturneColors.neutral500, height: 1.4),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 88,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -2,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(_dateStr, style: TextStyle(fontSize: 22, color: NocturneColors.neutral300)),
            ],
          ),
        ],
      ),
    );
  }
}
