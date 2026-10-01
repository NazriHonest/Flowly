import 'package:intl/intl.dart';

abstract final class MoneyFormatter {
  static String currencyCode = 'KES';
  static void configure(String code) =>
      currencyCode = code.trim().isEmpty ? 'KES' : code;
  static String symbolFor([String? code]) {
    switch ((code ?? currencyCode).trim().toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'KES':
        return 'KSh';
      case 'SOS':
        return 'S';
      default:
        return (code ?? currencyCode).trim().toUpperCase();
    }
  }

  static String format(int minorUnits, {String? code}) => NumberFormat.currency(
    name: (code ?? currencyCode).trim().toUpperCase(),
    symbol: symbolFor(code),
    decimalDigits: 2,
  ).format(minorUnits / 100);

  static String signed(
    int minorUnits, {
    String? code,
    required bool negative,
    bool plus = true,
  }) {
    final sign = negative ? '-' : (plus ? '+' : '');
    return '$sign${format(minorUnits.abs(), code: code)}';
  }
}
