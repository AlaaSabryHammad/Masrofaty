import 'package:intl/intl.dart';

class DateHelper {
  static final DateFormat _arabicDate = DateFormat('d MMMM yyyy', 'ar');
  static final DateFormat _shortDate = DateFormat('yyyy/MM/dd');
  static final DateFormat _timeFormat = DateFormat('h:mm a', 'ar');

  static String formatFriendly(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = target.difference(today).inDays;

    if (diffDays == 0) {
      return 'اليوم (${_timeFormat.format(date)})';
    } else if (diffDays == -1) {
      return 'أمس';
    } else if (diffDays == 1) {
      return 'غداً';
    } else if (diffDays > 1 && diffDays <= 7) {
      return 'بعد $diffDays أيام';
    } else if (diffDays < -1 && diffDays >= -7) {
      return 'منذ ${diffDays.abs()} أيام';
    }

    try {
      return _arabicDate.format(date);
    } catch (_) {
      return _shortDate.format(date);
    }
  }

  static String formatDate(DateTime date) {
    try {
      return _arabicDate.format(date);
    } catch (_) {
      return _shortDate.format(date);
    }
  }

  static String formatShort(DateTime date) {
    return _shortDate.format(date);
  }

  static String formatMonthYear(DateTime date) {
    try {
      return DateFormat('MMMM yyyy', 'ar').format(date);
    } catch (_) {
      return '${date.month}/${date.year}';
    }
  }

  static String getRelativeDueStatus(DateTime? dueDate) {
    if (dueDate == null) return 'غير محدد';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(today).inDays;

    if (diff < 0) {
      return 'متأخر منذ ${diff.abs()} يوم';
    } else if (diff == 0) {
      return 'يستحق اليوم!';
    } else if (diff == 1) {
      return 'يستحق غداً';
    } else {
      return 'متبقي $diff يوم';
    }
  }
}
