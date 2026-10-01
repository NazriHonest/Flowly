import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_local_datasource.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl(this._local);
  final TransactionLocalDatasource _local;
  @override
  Future<List<Transaction>> getAll() => _local.getAll();
  @override
  Future<void> save(Transaction transaction) => _local.save(transaction);
  @override
  Future<void> delete(int id) => _local.delete(id);
}
