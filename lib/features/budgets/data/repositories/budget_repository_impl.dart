import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/budget_local_datasource.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  const BudgetRepositoryImpl(this._local);

  final BudgetLocalDataSource _local;

  @override
  Future<List<Budget>> getActive() => _local.getActive();

  @override
  Future<void> save(Budget budget) => _local.save(budget);

  @override
  Future<void> archive(int id) => _local.archive(id);
}
