import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV3 implements DatabaseMigration {
  @override
  int get version => 3;
  @override
  Future<void> apply(Database d) async {
    await d.execute(
      'CREATE TABLE IF NOT EXISTS goals(id INTEGER PRIMARY KEY,name TEXT NOT NULL,target_amount INTEGER NOT NULL,current_amount INTEGER NOT NULL DEFAULT 0,target_date TEXT,account_id INTEGER)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS goal_contributions(id INTEGER PRIMARY KEY,goal_id INTEGER NOT NULL,amount INTEGER NOT NULL,contributed_at TEXT NOT NULL)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS recurring_transactions(id INTEGER PRIMARY KEY,amount INTEGER NOT NULL,type TEXT NOT NULL,category TEXT NOT NULL,account_id INTEGER NOT NULL,frequency TEXT NOT NULL,next_occurrence TEXT NOT NULL,is_enabled INTEGER NOT NULL DEFAULT 1)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS recurring_next_idx ON recurring_transactions(next_occurrence)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS merchant_rules(id INTEGER PRIMARY KEY,normalized_merchant TEXT NOT NULL UNIQUE,category TEXT NOT NULL)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS merchant_normalized_idx ON merchant_rules(normalized_merchant)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS notifications(id INTEGER PRIMARY KEY,title TEXT NOT NULL,body TEXT NOT NULL,created_at TEXT NOT NULL,is_read INTEGER NOT NULL DEFAULT 0)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS notifications_created_idx ON notifications(created_at)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS notifications_read_idx ON notifications(is_read)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS sms_providers(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE,is_enabled INTEGER NOT NULL DEFAULT 1)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS provider_account_mappings(id INTEGER PRIMARY KEY,provider_id INTEGER NOT NULL,account_id INTEGER NOT NULL,UNIQUE(provider_id,account_id))',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS transaction_fingerprints(fingerprint TEXT PRIMARY KEY,transaction_id INTEGER NOT NULL,created_at TEXT NOT NULL)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS app_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
    );
    await d.execute(
      'CREATE TABLE IF NOT EXISTS security_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
    );
  }
}
