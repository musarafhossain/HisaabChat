import 'package:intl/intl.dart';

/// WhatsApp-style date labels. All inputs are local times.
abstract final class Dates {
  static final _time = DateFormat.jm();
  static final _shortDate = DateFormat('d/M/yy');
  static final _weekday = DateFormat.EEEE();
  static final _longDate = DateFormat('d MMMM y');
  static final _dayMonth = DateFormat('d MMM');

  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  static int _daysAgo(DateTime value, DateTime now) => _day(now).difference(_day(value)).inDays;

  /// "7:45 pm"
  static String time(DateTime value) => _time.format(value).toLowerCase();

  /// Chat-list stamp: time today, "Yesterday", weekday this week, else d/M/yy.
  static String listStamp(DateTime value, {DateTime? now}) {
    final days = _daysAgo(value, now ?? DateTime.now());
    if (days == 0) return time(value);
    if (days == 1) return 'Yesterday';
    if (days > 1 && days < 7) return _weekday.format(value);
    return _shortDate.format(value);
  }

  /// Date chip in a thread: "TODAY", "YESTERDAY", weekday, or "8 OCTOBER 2026".
  static String dayChip(DateTime value, {DateTime? now}) {
    final days = _daysAgo(value, now ?? DateTime.now());
    if (days == 0) return 'TODAY';
    if (days == 1) return 'YESTERDAY';
    if (days > 1 && days < 7) return _weekday.format(value).toUpperCase();
    return _longDate.format(value).toUpperCase();
  }

  /// Form field label: "Today, 7:45 pm", "Yesterday, 9:00 am", "8 Oct, 6:00 pm".
  static String formLabel(DateTime value, {DateTime? now}) {
    final days = _daysAgo(value, now ?? DateTime.now());
    final day = switch (days) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => _dayMonth.format(value),
    };
    return '$day, ${time(value)}';
  }

  /// "8 Oct" (due dates, schedules).
  static String dayMonth(DateTime value) => _dayMonth.format(value);

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
