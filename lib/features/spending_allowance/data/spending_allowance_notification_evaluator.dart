import '../../../core/database/app_database.dart';
import '../../../core/formatters/money_formatter.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../../notifications/data/local_notification_service.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../data/spending_allowance_repository.dart';
import '../domain/entities/spending_allowance.dart';
import '../domain/services/spending_allowance_calculator.dart';

class SpendingAllowanceNotificationEvaluator {
  const SpendingAllowanceNotificationEvaluator(this._database);
  final AppDatabase _database;

  Future<void> evaluateLive(Transaction event, {Transaction? previous}) async {
    if (event.status != ReviewStatus.confirmed ||
        event.type != TransactionType.expense ||
        event.source == TransactionSource.smsImport) return;
    final eventDate = event.date.toLocal();
    final now = DateTime.now();
    if (eventDate.isBefore(now.subtract(const Duration(days: 1))) ||
        eventDate.isAfter(now.add(const Duration(minutes: 5)))) return;
    final transactions = await _database.transactions();
    final repository = SpendingAllowanceRepository(_database);
    for (final type in AllowancePeriodType.values) {
      final period = SpendingAllowanceCalculator.periodFor(type, eventDate);
      final config = await repository.configurationFor(
        type == AllowancePeriodType.monthly ? eventDate : period.start,
      );
      final limit = config?.limitFor(type);
      if (limit == null) continue;
      final summary = SpendingAllowanceCalculator.calculate(
        type: type,
        allowanceMinor: limit,
        transactions: transactions,
        at: eventDate,
      );
      final previousEligible = previous != null &&
              previous.status == ReviewStatus.confirmed &&
              previous.type == TransactionType.expense &&
              !previous.date.toLocal().isBefore(period.start) &&
              previous.date.toLocal().isBefore(period.end)
          ? previous.amountMinor
          : 0;
      final previousSpent =
          summary.spentMinor - event.amountMinor + previousEligible;
      final threshold = summary.spentMinor > limit && previousSpent <= limit
          ? 'over'
          : summary.spentMinor >= limit && previousSpent < limit
          ? 'reached'
          : summary.spentMinor * 100 >= limit * 80 && previousSpent * 100 < limit * 80
          ? 'warning'
          : null;
      if (threshold != null) await _emit(type, summary, threshold);
    }
  }

  Future<void> _emit(AllowancePeriodType type, SpendingAllowanceSummary summary, String threshold) async {
    final db = await _database.db;
    final inserted = await db.insert(
      'spending_allowance_notifications',
      {
        'period_type': type.name,
        'period_start': summary.period.start.toIso8601String(),
        'threshold': threshold,
        'policy_version': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (inserted == 0) return;
    final label = type.name[0].toUpperCase() + type.name.substring(1);
    final title = threshold == 'over'
        ? '$label Allowance Exceeded'
        : threshold == 'reached'
        ? '$label Spending Limit Reached'
        : '$label Spending Warning';
    final body = threshold == 'over'
        ? "You've exceeded your ${type.name} allowance by ${MoneyFormatter.format(-summary.remainingMinor)}."
        : threshold == 'reached'
        ? "You've reached your ${type.name} spending limit of ${MoneyFormatter.format(summary.limitMinor)}."
        : "You've used 80% of your ${type.name} allowance. ${MoneyFormatter.format(summary.remainingMinor)} remains.";
    await _database.createNotification(title, body);
    await LocalNotificationService.instance.show(
      event: 'spendingAllowance',
      id: Object.hash(type.name, summary.period.start.millisecondsSinceEpoch, threshold),
      title: title,
      body: body,
    );
  }
}
