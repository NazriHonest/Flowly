import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/spending_allowance.dart';

class SpendingAllowanceRepository {
  const SpendingAllowanceRepository(this._database);
  final AppDatabase _database;

  DateTime _month(DateTime date) => DateTime(date.year, date.month);

  Future<SpendingAllowanceConfig?> configurationFor(DateTime date) async {
    final month = _month(date.toLocal());
    final database = await _database.db;
    final exact = await database.query(
      'spending_allowance_configs',
      where: 'month_start=?',
      whereArgs: [month.toIso8601String()],
      limit: 1,
    );
    if (exact.isNotEmpty) return _config(exact.first, month);
    final defaults = await database.query(
      'spending_allowance_defaults',
      where: 'effective_from<=?',
      whereArgs: [month.toIso8601String()],
      orderBy: 'effective_from DESC',
      limit: 1,
    );
    if (defaults.isEmpty) return null;
    return _config(defaults.first, month, repeats: true);
  }

  Future<List<DateTime>> configuredMonths() async => (await _database.db)
      .query('spending_allowance_configs', columns: ['month_start'], orderBy: 'month_start DESC')
      .then((rows) => rows.map((row) => DateTime.parse(row['month_start'] as String)).toList());

  Future<void> save(SpendingAllowanceConfig config) async {
    _validate(config);
    final database = await _database.db;
    final month = _month(config.monthStart.toLocal()).toIso8601String();
    final now = DateTime.now().toUtc().toIso8601String();
    final values = <String, Object?>{
      'monthly_limit': config.monthlyLimitMinor,
      'weekly_enabled': config.weeklyEnabled ? 1 : 0,
      'weekly_limit': config.weeklyEnabled ? config.weeklyLimitMinor : null,
      'daily_enabled': config.dailyEnabled ? 1 : 0,
      'daily_limit': config.dailyEnabled ? config.dailyLimitMinor : null,
      'notes': config.notes,
      'updated_at': now,
    };
    await database.transaction((txn) async {
      await txn.insert(
        'spending_allowance_configs',
        {...values, 'month_start': month, 'repeats_monthly': config.repeatsMonthly ? 1 : 0, 'created_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (config.repeatsMonthly) {
        await txn.insert(
          'spending_allowance_defaults',
          {...values, 'effective_from': month, 'created_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  void _validate(SpendingAllowanceConfig value) {
    if (value.monthlyLimitMinor <= 0 ||
        (value.weeklyEnabled && (value.weeklyLimitMinor ?? 0) <= 0) ||
        (value.dailyEnabled && (value.dailyLimitMinor ?? 0) <= 0)) {
      throw ArgumentError('All enabled allowance limits must be greater than zero.');
    }
  }

  SpendingAllowanceConfig _config(Map<String, Object?> row, DateTime month, {bool? repeats}) =>
      SpendingAllowanceConfig(
        id: row['id'] as int?,
        monthStart: month,
        monthlyLimitMinor: row['monthly_limit'] as int,
        weeklyEnabled: row['weekly_enabled'] == 1,
        weeklyLimitMinor: row['weekly_limit'] as int?,
        dailyEnabled: row['daily_enabled'] == 1,
        dailyLimitMinor: row['daily_limit'] as int?,
        repeatsMonthly: repeats ?? row['repeats_monthly'] == 1,
        notes: row['notes'] as String?,
      );
}
