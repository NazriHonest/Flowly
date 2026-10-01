import 'package:intl/intl.dart';

abstract final class DateFormatter {
  static String transaction(DateTime value) =>
      DateFormat.yMMMd().add_jm().format(value);
  static String short(DateTime value) => DateFormat.MMMd().format(value);
}
