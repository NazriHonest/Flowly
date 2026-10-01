import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/transaction.dart';
import '../domain/repositories/transaction_repository.dart';
import '../data/datasources/transaction_local_datasource.dart';
import '../data/repositories/transaction_repository_impl.dart';
import '../../../core/database/app_database.dart';
import '../../notifications/data/budget_notification_evaluator.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (_) => TransactionRepositoryImpl(
    TransactionLocalDatasource(AppDatabase.instance),
  ),
);

class TransactionController
    extends StateNotifier<AsyncValue<List<Transaction>>> {
  TransactionController(this._repository) : super(const AsyncLoading()) {
    refresh();
  }
  final TransactionRepository _repository;
  Future<void> refresh() async {
    state = AsyncData(await _repository.getAll());
  }

  Future<void> save(Transaction t) async {
    await _repository.save(t);
    await refresh();
    await BudgetNotificationEvaluator(AppDatabase.instance).evaluate();
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    await refresh();
  }

  Future<void> linkTransfer({
    required int outgoingTransactionId,
    required int incomingTransactionId,
  }) async {
    await AppDatabase.instance.linkTransfer(
      outgoingTransactionId: outgoingTransactionId,
      incomingTransactionId: incomingTransactionId,
    );
    await refresh();
    await BudgetNotificationEvaluator(AppDatabase.instance).evaluate();
  }

  Future<void> unlinkTransfer(int outgoingTransactionId) async {
    await AppDatabase.instance.unlinkTransfer(outgoingTransactionId);
    await refresh();
    await BudgetNotificationEvaluator(AppDatabase.instance).evaluate();
  }
}

final transactionListProvider =
    StateNotifierProvider<TransactionController, AsyncValue<List<Transaction>>>(
      (ref) => TransactionController(ref.read(transactionRepositoryProvider)),
    );
