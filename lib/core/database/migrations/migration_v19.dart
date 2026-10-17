import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV19 implements DatabaseMigration {
  @override
  int get version => 19;

  @override
  Future<void> apply(Database database) async {
    await database.execute('''
      CREATE TABLE spending_allowance_defaults(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        effective_from TEXT NOT NULL UNIQUE,
        monthly_limit INTEGER NOT NULL CHECK(monthly_limit > 0),
        weekly_enabled INTEGER NOT NULL DEFAULT 0,
        weekly_limit INTEGER CHECK(weekly_limit IS NULL OR weekly_limit > 0),
        daily_enabled INTEGER NOT NULL DEFAULT 0,
        daily_limit INTEGER CHECK(daily_limit IS NULL OR daily_limit > 0),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(weekly_enabled = 0 OR weekly_limit IS NOT NULL),
        CHECK(daily_enabled = 0 OR daily_limit IS NOT NULL)
      )
    ''');
    await database.execute('''
      CREATE TABLE spending_allowance_configs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_start TEXT NOT NULL UNIQUE,
        monthly_limit INTEGER NOT NULL CHECK(monthly_limit > 0),
        weekly_enabled INTEGER NOT NULL DEFAULT 0,
        weekly_limit INTEGER CHECK(weekly_limit IS NULL OR weekly_limit > 0),
        daily_enabled INTEGER NOT NULL DEFAULT 0,
        daily_limit INTEGER CHECK(daily_limit IS NULL OR daily_limit > 0),
        repeats_monthly INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(weekly_enabled = 0 OR weekly_limit IS NOT NULL),
        CHECK(daily_enabled = 0 OR daily_limit IS NOT NULL)
      )
    ''');
    await database.execute('''
      CREATE TABLE spending_allowance_notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_type TEXT NOT NULL,
        period_start TEXT NOT NULL,
        threshold TEXT NOT NULL,
        policy_version INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        UNIQUE(period_type, period_start, threshold, policy_version)
      )
    ''');
    await database.execute(
      'CREATE INDEX allowance_defaults_effective_idx ON spending_allowance_defaults(effective_from)',
    );
    await database.execute(
      'CREATE INDEX tx_allowance_idx ON transactions(type, status, transaction_date)',
    );
  }
}
