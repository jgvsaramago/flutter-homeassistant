/// A Home Assistant entity state, as returned by `get_states` and updated by
/// `state_changed` events.
class HaEntity {
  const HaEntity({
    required this.entityId,
    required this.state,
    required this.attributes,
    required this.lastChanged,
    required this.lastUpdated,
  });

  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;
  final DateTime lastChanged;
  final DateTime lastUpdated;

  /// The part of the entity id before the dot, e.g. `light`, `sensor`.
  String get domain => entityId.split('.').first;

  /// The friendly name, falling back to a title-cased object id.
  String get friendlyName {
    final name = attributes['friendly_name'];
    if (name is String && name.isNotEmpty) return name;
    final objectId = entityId.split('.').skip(1).join('.');
    return objectId.replaceAll('_', ' ');
  }

  String? get unitOfMeasurement => attributes['unit_of_measurement'] as String?;

  String? get deviceClass => attributes['device_class'] as String?;

  bool get isUnavailable => state == 'unavailable' || state == 'unknown';

  bool get isOn => state == 'on';

  /// [state] rounded to 1 decimal place when it's actually numeric, plus
  /// the unit if any — e.g. "18.7°C" rather than a raw "18.722222222222"
  /// (some integrations report far more precision than is useful, which is
  /// enough to overflow a card at full precision). Falls back to the raw
  /// state string for non-numeric states (`on`, `unavailable`, etc.).
  String get displayState {
    final numeric = double.tryParse(state);
    final value = numeric != null ? numeric.toStringAsFixed(1) : state;
    final unit = unitOfMeasurement;
    return unit != null ? '$value$unit' : value;
  }

  factory HaEntity.fromJson(Map<String, dynamic> json) {
    return HaEntity(
      entityId: json['entity_id'] as String,
      state: json['state'] as String? ?? 'unknown',
      attributes: (json['attributes'] as Map?)?.cast<String, dynamic>() ?? const {},
      lastChanged: DateTime.tryParse(json['last_changed'] as String? ?? '') ?? DateTime.now(),
      lastUpdated: DateTime.tryParse(json['last_updated'] as String? ?? '') ?? DateTime.now(),
    );
  }

  HaEntity copyWith({String? state, Map<String, dynamic>? attributes, DateTime? lastChanged, DateTime? lastUpdated}) {
    return HaEntity(
      entityId: entityId,
      state: state ?? this.state,
      attributes: attributes ?? this.attributes,
      lastChanged: lastChanged ?? this.lastChanged,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
