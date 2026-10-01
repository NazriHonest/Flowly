import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/datasources/budget_local_datasource.dart';
import '../data/repositories/budget_repository_impl.dart';
import '../domain/entities/budget.dart';
import '../domain/repositories/budget_repository.dart';

class BudgetController extends StateNotifier<AsyncValue<List<Budget>>> {
  BudgetController(this._repository) : super(const AsyncLoading()) {
    refresh();
  }
  final BudgetRepository _repository;
  Future<void> refresh() async =>
      state = AsyncData(await _repository.getActive());
  Future<void> save(Budget b) async {
    await _repository.save(b);
    await refresh();
  }

  Future<void> archive(int id) async {
    await _repository.archive(id);
    await refresh();
  }
}

final budgetListProvider =
    StateNotifierProvider<BudgetController, AsyncValue<List<Budget>>>(
      (_) => BudgetController(
        BudgetRepositoryImpl(BudgetLocalDataSource(AppDatabase.instance)),
      ),
    );
