import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

/// Stores period-specific budget settings without freezing calculated spend.
///
/// Existing installations deliberately receive no fabricated historical rows.
/// The current period is captured when the application next opens or the
/// budget is saved; subsequent periods are captured as they become current.
class MigrationV18 implements DatabaseMigration {
  @override
  int get version => 18;

  @override
  Future<void> apply(Database database) async {
    await database.execute('''
      CREATE TABLE budget_period_limits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        budget_id INTEGER NOT NULL REFERENCES budgets(id),
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category TEXT NOT NULL,
        period TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(budget_id, period_start, period_end)
      )
    ''');
    await database.execute(
      'CREATE INDEX budget_period_limits_budget_idx '
      'ON budget_period_limits(budget_id, period_start)',
    );
    await database.execute(
      'CREATE INDEX tx_budget_history_idx '
      'ON transactions(category, type, status, transaction_date)',
    );
  }
}
