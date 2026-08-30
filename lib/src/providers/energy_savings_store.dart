import 'package:shared_preferences/shared_preferences.dart';

/// Rolls a continuously-recomputed "today's savings so far" figure into a
/// running month-to-date total, persisted locally. There's no HA statistics
/// API this app's plain websocket client can reach for a true historical
/// month total (`historyDuringPeriod` only returns raw state samples, not
/// long-term stats), so this is a best-effort approximation: it only
/// accumulates while the kiosk is running and this page's savings figure is
/// actually recomputed (every few minutes whenever the Energia tab is
/// visible), and a day the app was off for entirely contributes nothing.
/// Good enough for an always-on kiosk; resets to 0 whenever the calendar
/// month changes.
class EnergySavingsStore {
  EnergySavingsStore();

  static const _monthKey = 'energy_savings_month';
  static const _monthTotalKey = 'energy_savings_month_total';
  static const _dayKey = 'energy_savings_day';
  static const _dayTotalKey = 'energy_savings_day_total';

  /// Folds [todaySavings] (this app's current best estimate of how much
  /// today has saved so far) into the persisted month total and returns the
  /// resulting month-to-date figure. Safe to call repeatedly with an
  /// updated `todaySavings` as the day progresses — each call replaces
  /// today's own contribution rather than adding to it again.
  Future<double> recordToday(double todaySavings, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final date = now ?? DateTime.now();
    final monthKey = '${date.year}-${date.month}';
    final dayKey = '${date.year}-${date.month}-${date.day}';

    var monthTotal = prefs.getString(_monthKey) == monthKey ? (prefs.getDouble(_monthTotalKey) ?? 0) : 0.0;
    final storedDayKey = prefs.getString(_dayKey);

    if (storedDayKey != null && storedDayKey != dayKey && prefs.getString(_monthKey) == monthKey) {
      // A previous day's running total never got folded in (the app wasn't
      // open right as the date rolled over) — fold it in now rather than
      // losing it.
      monthTotal += prefs.getDouble(_dayTotalKey) ?? 0;
    }

    await prefs.setString(_monthKey, monthKey);
    await prefs.setDouble(_monthTotalKey, monthTotal);
    await prefs.setString(_dayKey, dayKey);
    await prefs.setDouble(_dayTotalKey, todaySavings);

    return monthTotal + todaySavings;
  }
}
