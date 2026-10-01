import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV6 implements DatabaseMigration {
  @override
  int get version => 6;

  @override
  Future<void> apply(Database database) async {
    await database.execute(
      "ALTER TABLE categories ADD COLUMN created_at TEXT NOT NULL DEFAULT ''",
    );
    await database.execute(
      "ALTER TABLE categories ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''",
    );
    final now = DateTime.now().toIso8601String();
    const defaults = <Map<String, Object>>[
      {
        'name': 'Groceries',
        'icon': 0xe59c,
        'color': 0xff16a34a,
        'type': 'expense',
      },
      {
        'name': 'Food & dining',
        'icon': 0xe532,
        'color': 0xfff97316,
        'type': 'expense',
      },
      {
        'name': 'Transport',
        'icon': 0xe1d5,
        'color': 0xff0284c7,
        'type': 'expense',
      },
      {'name': 'Bills', 'icon': 0xe8a1, 'color': 0xffdc2626, 'type': 'expense'},
      {
        'name': 'Health',
        'icon': 0xe3f3,
        'color': 0xffec4899,
        'type': 'expense',
      },
      {
        'name': 'Shopping',
        'icon': 0xe8cc,
        'color': 0xff8b5cf6,
        'type': 'expense',
      },
      {'name': 'Salary', 'icon': 0xe8f9, 'color': 0xff16a34a, 'type': 'income'},
      {
        'name': 'Savings',
        'icon': 0xe2e6,
        'color': 0xff079669,
        'type': 'income',
      },
      {'name': 'Other', 'icon': 0xe8b6, 'color': 0xff64748b, 'type': 'both'},
    ];
    for (final category in defaults) {
      await database.insert('categories', {
        ...category,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
