import 'package:intl/intl.dart';

class DateTimeUtils {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static DateFormat get _monthYearFormat {
    try {
      return DateFormat('MMMM yyyy', 'pt_BR');
    } catch (_) {
      return DateFormat('MM/yyyy');
    }
  }
  static DateFormat get _shortMonthFormat {
    try {
      return DateFormat('MMM/yy', 'pt_BR');
    } catch (_) {
      return DateFormat('MM/yy');
    }
  }

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);
  static String formatShortMonth(DateTime date) => _shortMonthFormat.format(date);

  static DateTime getNextBusinessDay(DateTime date, {List<DateTime>? holidays}) {
    var candidate = DateTime(date.year, date.month, date.day);

    while (isWeekend(candidate) || isHoliday(candidate, holidays: holidays)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  static bool isHoliday(DateTime date, {List<DateTime>? holidays}) {
    if (holidays == null || holidays.isEmpty) {
      final fixedHolidays = [
        DateTime(date.year, 1, 1),
        DateTime(date.year, 4, 21),
        DateTime(date.year, 5, 1),
        DateTime(date.year, 9, 7),
        DateTime(date.year, 10, 12),
        DateTime(date.year, 11, 2),
        DateTime(date.year, 11, 15),
        DateTime(date.year, 11, 20),
        DateTime(date.year, 12, 25),
      ];
      return fixedHolidays.any((h) => h.year == date.year && h.month == date.month && h.day == date.day);
    }
    return holidays.any((h) => h.year == date.year && h.month == date.month && h.day == date.day);
  }

  static DateTime calculateDueDate(int year, int month, int dueDay, {List<DateTime>? holidays}) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final actualDay = dueDay > daysInMonth ? daysInMonth : dueDay;
    final nominalDate = DateTime(year, month, actualDay);
    return getNextBusinessDay(nominalDate, holidays: holidays);
  }

  static DateTime calculateClosingDate(int year, int month, int closingDay) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final actualDay = closingDay > daysInMonth ? daysInMonth : closingDay;
    return DateTime(year, month, actualDay);
  }
}
