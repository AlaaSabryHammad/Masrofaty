import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _compactFormatter = NumberFormat.compact(locale: 'en_US');

  static String format(double amount, {String symbol = 'ر.س', bool hide = false}) {
    if (hide) return '•••••• $symbol';
    return '${_formatter.format(amount)} $symbol';
  }

  static String formatCompact(double amount, {String symbol = 'ر.س', bool hide = false}) {
    if (hide) return '•••• $symbol';
    return '${_compactFormatter.format(amount)} $symbol';
  }

  static String formatPlain(double amount) {
    return _formatter.format(amount);
  }
}
