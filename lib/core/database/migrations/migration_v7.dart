import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV7 implements DatabaseMigration {
  @override
  int get version => 7;

  @override
  Future<void> apply(Database database) async {
    await database.execute(
      "ALTER TABLE budgets ADD COLUMN name TEXT NOT NULL DEFAULT ''",
    );
    await database.execute(
      "ALTER TABLE budgets ADD COLUMN period TEXT NOT NULL DEFAULT 'monthly'",
    );
    await database.execute(
      "ALTER TABLE budgets ADD COLUMN start_date TEXT NOT NULL DEFAULT ''",
    );
    await database.execute(
      'ALTER TABLE budgets ADD COLUMN alert_threshold REAL NOT NULL DEFAULT 0.8',
    );
    await database.execute(
      'ALTER TABLE budgets ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
    );
    await database.execute("UPDATE budgets SET name=category WHERE name='' ");
  }
}
