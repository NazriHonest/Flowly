import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../transactions/domain/entities/transaction.dart';
import 'local_notification_service.dart';

/// Generates one notification per budget state in a budget period. State is
/// persisted so provider rebuilds and ordinary transaction edits cannot spam.
class BudgetNotificationEvaluator {
  const BudgetNotificationEvaluator(this._database);

  final AppDatabase _database;

  Future<void> evaluate() async {
    final budgets = await _database.budgets();
    final transactions = await _database.transactions();
    final now = DateTime.now();
    final preferences = await SharedPreferences.getInstance();
    for (final budget in budgets) {
      final spent = transactions
          .where(
            (transaction) =>
                transaction.status == ReviewStatus.confirmed &&
                transaction.type == TransactionType.expense &&
                transaction.category == budget.category &&
                _inBudgetPeriod(transaction.date, budget.period, now),
          )
          .fold<int>(0, (sum, transaction) => sum + transaction.amountMinor);
      final ratio = budget.amountMinor == 0 ? 0 : spent / budget.amountMinor;
      final period = '${now.year}-${now.month}-${budget.period}';
      if (ratio >= 1) {
        await _emitOnce(
          preferences,
          key: 'budget.exceeded.${budget.id}.$period',
          event: 'budgetExceeded',
          id: (budget.id! * 100000) + now.month,
          title: 'Budget exceeded',
          body: '${budget.name} has exceeded its budget.',
        );
      } else if (ratio >= budget.alertThreshold) {
        await _emitOnce(
          preferences,
          key: 'budget.warning.${budget.id}.$period',
          event: 'budgetWarning',
          id: (budget.id! * 100000) + now.month + 50000,
          title: 'Budget threshold reached',
          body:
              '${budget.name} has reached ${(ratio * 100).round()}% of its budget.',
        );
      }
    }
  }

  bool _inBudgetPeriod(DateTime date, String period, DateTime now) =>
      switch (period) {
        'weekly' => !date.isBefore(now.subtract(const Duration(days: 6))),
        'yearly' => date.year == now.year,
        _ => date.year == now.year && date.month == now.month,
      };

  Future<void> _emitOnce(
    SharedPreferences preferences, {
    required String key,
    required String event,
    required int id,
    required String title,
    required String body,
  }) async {
    if (preferences.getBool(key) ?? false) return;
    await _database.createNotification(title, body);
    await LocalNotificationService.instance.show(
      event: event,
      id: id,
      title: title,
      body: body,
    );
    await preferences.setBool(key, true);
  }
}
