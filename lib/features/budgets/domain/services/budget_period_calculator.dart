import 'package:intl/intl.dart';

import '../entities/budget.dart';

class BudgetPeriodBounds {
  const BudgetPeriodBounds(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

/// Calendar boundaries used by budget details and history.
///
/// Weekly budgets retain SpenFlo's established rolling-seven-day semantics.
abstract final class BudgetPeriodCalculator {
  static BudgetPeriodBounds current(Budget budget, {DateTime? asOf}) {
    final now = _dateOnly((asOf ?? DateTime.now()).toLocal());
    late DateTime start;
    late DateTime end;
    switch (budget.period) {
      case 'weekly':
        start = now.subtract(const Duration(days: 6));
        end = now;
        break;
      case 'yearly':
        start = DateTime(now.year);
        end = DateTime(now.year, 12, 31);
        break;
      default:
        start = DateTime(now.year, now.month);
        end = DateTime(now.year, now.month + 1, 0);
        break;
    }
    final configured = budget.startDate == null
        ? null
        : _dateOnly(budget.startDate!.toLocal());
    if (configured != null && configured.isAfter(start)) start = configured;
    return BudgetPeriodBounds(start, end);
  }

  static List<BudgetPeriodBounds> recent(
    Budget budget,
    int count, {
    DateTime? asOf,
  }) {
    final currentBounds = current(budget, asOf: asOf);
    final result = <BudgetPeriodBounds>[];
    for (var offset = count - 1; offset >= 0; offset--) {
      late BudgetPeriodBounds bounds;
      switch (budget.period) {
        case 'weekly':
          final end = currentBounds.end.subtract(Duration(days: offset * 7));
          bounds = BudgetPeriodBounds(
            end.subtract(const Duration(days: 6)),
            end,
          );
          break;
        case 'yearly':
          final year = currentBounds.end.year - offset;
          bounds = BudgetPeriodBounds(DateTime(year), DateTime(year, 12, 31));
          break;
        default:
          final month = DateTime(
            currentBounds.end.year,
            currentBounds.end.month - offset,
          );
          bounds = BudgetPeriodBounds(
            DateTime(month.year, month.month),
            DateTime(month.year, month.month + 1, 0),
          );
          break;
      }
      final configured = budget.startDate == null
          ? null
          : _dateOnly(budget.startDate!.toLocal());
      if (configured != null && bounds.end.isBefore(configured)) continue;
      if (configured != null && configured.isAfter(bounds.start)) {
        bounds = BudgetPeriodBounds(configured, bounds.end);
      }
      result.add(bounds);
    }
    return result;
  }

  static String label(BudgetPeriodBounds bounds, String period) {
    switch (period) {
      case 'weekly':
        final formatter = DateFormat('MMM d');
        return '${formatter.format(bounds.start)} – ${formatter.format(bounds.end)}';
      case 'yearly':
        return '${bounds.start.year}';
      default:
        return DateFormat('MMMM yyyy').format(bounds.start);
    }
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
