import '../../../../core/database/app_database.dart';
import '../../domain/entities/budget.dart';

/// SQLite boundary for the budgets feature.
class BudgetLocalDataSource {
  const BudgetLocalDataSource(this._database);

  final AppDatabase _database;

  Future<List<Budget>> getActive() => _database.budgets();
  Future<void> save(Budget budget) => _database.saveBudget(budget);
  Future<void> archive(int id) => _database.archiveBudget(id);
}
