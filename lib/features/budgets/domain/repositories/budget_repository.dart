import '../entities/budget.dart';

abstract interface class BudgetRepository {
  Future<List<Budget>> getActive();
  Future<void> save(Budget budget);
  Future<void> archive(int id);
}
