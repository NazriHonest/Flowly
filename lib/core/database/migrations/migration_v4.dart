import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV4 implements DatabaseMigration {
  @override
  int get version => 4;
  @override
  Future<void> apply(Database d) async {
    await d.execute(
      'CREATE TABLE IF NOT EXISTS budget_categories(budget_id INTEGER NOT NULL,category_id INTEGER NOT NULL,PRIMARY KEY(budget_id,category_id))',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS categorization_rules(id INTEGER PRIMARY KEY,kind TEXT NOT NULL,pattern TEXT NOT NULL,category_id INTEGER,priority INTEGER NOT NULL DEFAULT 0,is_enabled INTEGER NOT NULL DEFAULT 1)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS receipts(id INTEGER PRIMARY KEY,transaction_id INTEGER NOT NULL,path TEXT NOT NULL,created_at TEXT NOT NULL)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS receipts_transaction_idx ON receipts(transaction_id)',
    );
  }
}
