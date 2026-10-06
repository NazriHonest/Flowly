import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

/// Adds generic linked-account configuration and privacy-safe normalized SMS
/// observations. Observations are evidence only; `transactions` remains the
/// sole accounting ledger.
class MigrationV17 implements DatabaseMigration {
  @override
  int get version => 17;

  @override
  Future<void> apply(Database database) async {
    await database.execute(
      'ALTER TABLE provider_account_mappings ADD COLUMN linked_account_id INTEGER REFERENCES accounts(id)',
    );
    await database.execute('''
      CREATE TABLE sms_transfer_observations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER REFERENCES transactions(id),
        provider_id INTEGER NOT NULL REFERENCES sms_providers(id),
        mapped_account_id INTEGER NOT NULL REFERENCES accounts(id),
        linked_account_id INTEGER REFERENCES accounts(id),
        direction TEXT NOT NULL,
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL,
        account_hint_hash TEXT,
        provider_transaction_at TEXT,
        sms_received_at TEXT NOT NULL,
        source TEXT NOT NULL,
        fingerprint TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX sms_transfer_observation_match_idx ON sms_transfer_observations(amount,currency,direction,status,sms_received_at)',
    );
    await database.execute(
      'CREATE INDEX sms_transfer_observation_transaction_idx ON sms_transfer_observations(transaction_id)',
    );
    for (final provider in ['EVC Plus', 'JEEB', 'DEEQTOON', 'AGROBANK']) {
      await database.insert('sms_providers', {
        'name': provider,
        'sender_aliases': '',
        'is_enabled': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
