import 'package:flutter/material.dart';

import '../providers/individual_sensors_store.dart';
import '../theme/nocturne_theme.dart';
import 'boiler_icon.dart';

/// Resolves an [IndividualSensorIconKey] to the glyph the energy-flow
/// card's device nodes (and the settings icon picker) actually draw — one
/// place shared by both so they can never drift apart.
Widget individualSensorIcon(IndividualSensorIconKey key, {double size = 22, Color? color}) {
  color ??= NocturneColors.neutral300;
  switch (key) {
    case IndividualSensorIconKey.plug:
      return Icon(Icons.power_outlined, size: size, color: color);
    case IndividualSensorIconKey.washer:
      return Icon(Icons.local_laundry_service_outlined, size: size, color: color);
    case IndividualSensorIconKey.fridge:
      return Icon(Icons.kitchen_outlined, size: size, color: color);
    case IndividualSensorIconKey.tv:
      return Icon(Icons.tv_outlined, size: size, color: color);
    case IndividualSensorIconKey.ac:
      return Icon(Icons.ac_unit, size: size, color: color);
    case IndividualSensorIconKey.boiler:
      return BoilerIcon(size: size, color: color);
  }
}
