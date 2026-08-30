/// A single (time, numeric state) sample from Home Assistant's recorder
/// history, as used to plot a sensor over time.
class HaHistoryPoint {
  const HaHistoryPoint({required this.time, required this.value});

  final DateTime time;
  final double value;
}
