/// Recursively replaces blank/whitespace-only strings with `null` in a
/// settings JSON value before it's sent to HA storage — mirrors what every
/// `SharedPreferences`-based store used to do implicitly via `prefs.remove()`
/// for an empty field (an `EntityIdField`/text field reports `''`, not
/// `null`, when cleared).
dynamic blankStringsToNull(dynamic value) {
  if (value is String) return value.trim().isEmpty ? null : value;
  if (value is Map) return value.map((k, v) => MapEntry(k, blankStringsToNull(v)));
  if (value is List) return value.map(blankStringsToNull).toList();
  return value;
}
