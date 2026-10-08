import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../budgets/domain/services/budget_spending_calculator.dart';
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
      final spent = BudgetSpendingCalculator.spent(
        budget,
        transactions,
        asOf: now,
      );
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
