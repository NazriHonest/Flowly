import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV1 implements DatabaseMigration {
  @override
  int get version => 1;
  @override
  Future<void> apply(Database d) async {
    await d.execute(
      'CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY,name TEXT NOT NULL,opening_balance INTEGER NOT NULL,color INTEGER NOT NULL)',
    );
    await d.execute(
      "CREATE TABLE IF NOT EXISTS transactions(id INTEGER PRIMARY KEY,amount INTEGER NOT NULL,type TEXT NOT NULL,title TEXT NOT NULL,category TEXT NOT NULL,account_id INTEGER NOT NULL REFERENCES accounts(id),transaction_date TEXT NOT NULL,source TEXT NOT NULL,status TEXT NOT NULL,notes TEXT NOT NULL DEFAULT '',fingerprint TEXT UNIQUE)",
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS tx_date_idx ON transactions(transaction_date)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS budgets(id INTEGER PRIMARY KEY,category TEXT UNIQUE NOT NULL,amount INTEGER NOT NULL)',
    );
  }
}
