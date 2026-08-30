/// pt-PT number formatting shared by the Energia page — decimal comma, a
/// space before the unit, no `intl` dependency in this app (see
/// `energy_flow_card.dart`'s own `_formatKw` for the same reasoning).
String ptNumber(double value, {int decimals = 1}) => value.toStringAsFixed(decimals).replaceAll('.', ',');

String? formatKwh(double? kwh, {int decimals = 1}) => kwh == null ? null : '${ptNumber(kwh, decimals: decimals)} kWh';

String? formatKw(double? kw, {int decimals = 1}) => kw == null ? null : '${ptNumber(kw, decimals: decimals)} kW';

String? formatEuro(double? value, {int decimals = 2}) => value == null ? null : '${ptNumber(value, decimals: decimals)} €';

String? formatPercent(double? value) => value == null ? null : '${value.round()}%';
