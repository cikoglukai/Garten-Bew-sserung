import 'package:intl/intl.dart';

/// Date/time formatting shared across the watering history UI.
///
/// The DateFormat objects are created once and reused (parsing a pattern is
/// relatively expensive), so callers just use the static helpers.
class DateFormatting {
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _dayMonth = DateFormat('EEE, MMM d');

  /// A short, human-friendly "last watered" label, e.g. "Today 14:05",
  /// "Yesterday 09:12" or "Apr 3, 2026".
  static String lastWatered(DateTime when) {
    // Compare calendar days (date only, time stripped) so "Today"/"Yesterday"
    // are about the day, not a 24h window.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(when.year, when.month, when.day);
    final diffDays = today.difference(that).inDays;

    if (diffDays == 0) return 'Today ${_time.format(when)}';
    if (diffDays == 1) return 'Yesterday ${_time.format(when)}';
    return _date.format(when); // older than yesterday: show the full date
  }

  /// Time of day only, e.g. "14:05".
  static String time(DateTime when) => _time.format(when);

  /// Full weekday + date heading, e.g. "Thu, May 28".
  static String dayHeading(DateTime when) => _dayMonth.format(when);
}
