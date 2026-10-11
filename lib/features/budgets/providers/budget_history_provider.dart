import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../domain/entities/budget.dart';
import '../domain/entities/budget_history.dart';
import '../domain/services/budget_period_calculator.dart';

typedef BudgetHistoryRequest = ({Budget budget, int periodCount});

final budgetHistoryProvider = FutureProvider.autoDispose
    .family<BudgetHistory, BudgetHistoryRequest>((ref, request) async {
      // The database query is intentionally repeated whenever the canonical
      // transaction provider changes. This covers add, edit, delete and review
      // status changes without freezing historical spend totals.
      ref.watch(transactionListProvider);

      final budget = request.budget;
      final database = AppDatabase.instance;
      await database.recordCurrentBudgetLimit(budget);

      final bounds = BudgetPeriodCalculator.recent(budget, request.periodCount);
      if (bounds.isEmpty) return const BudgetHistory([]);

      final snapshots = budget.id == null
          ? const <BudgetLimitSnapshot>[]
          : await database.budgetLimitSnapshots(budget.id!);
      final transactions = await database.budgetHistoryTransactions(
        start: bounds.first.start,
        end: bounds.last.end,
      );
      final current = BudgetPeriodCalculator.current(budget);

      final periods = bounds
          .map((periodBounds) {
            final snapshot = snapshots.where((item) {
              return _sameDay(item.start, periodBounds.start) &&
                  _sameDay(item.end, periodBounds.end) &&
                  item.period == budget.period;
            }).firstOrNull;
            final category = snapshot?.category ?? budget.category;
            final periodTransactions = transactions.where((transaction) {
              final date = _dateOnly(transaction.date.toLocal());
              return !date.isBefore(periodBounds.start) &&
                  !date.isAfter(periodBounds.end) &&
                  transaction.category == category;
            }).toList()..sort((a, b) => b.date.compareTo(a.date));
            return BudgetHistoryPeriod(
              start: periodBounds.start,
              end: periodBounds.end,
              label: BudgetPeriodCalculator.label(periodBounds, budget.period),
              category: category,
              spentMinor: periodTransactions.fold<int>(
                0,
                (sum, transaction) => sum + transaction.amountMinor,
              ),
              limitMinor: snapshot?.amountMinor,
              transactions: List<Transaction>.unmodifiable(periodTransactions),
              isCurrent:
                  _sameDay(periodBounds.start, current.start) &&
                  _sameDay(periodBounds.end, current.end),
            );
          })
          .toList(growable: false);

      return BudgetHistory(periods);
    });

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
