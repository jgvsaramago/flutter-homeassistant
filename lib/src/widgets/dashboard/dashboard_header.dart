import 'dart:async';

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              '$_greeting,',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, height: 1.15),
            ),
          ),
          Text(
            time,
            // Proportional figures, deliberately not `tabularNums` — this
            // app's own default numeral style everywhere else, chosen over
            // tabular alignment so this "1" matches every other "1" in the
            // app instead of using Inter's wider tabular-figure variant.
            // The trade-off: the clock's width can shift by a pixel or two
            // as digits change, since digits are no longer fixed-width.
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 80,
              fontWeight: FontWeight.w600,
              letterSpacing: -2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
