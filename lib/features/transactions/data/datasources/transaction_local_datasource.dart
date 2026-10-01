import '../../../../core/database/app_database.dart';
import '../../domain/entities/transaction.dart';

class TransactionLocalDatasource {
  const TransactionLocalDatasource(this._database);
  final AppDatabase _database;
  Future<List<Transaction>> getAll() => _database.transactions();
  Future<void> save(Transaction transaction) =>
      _database.saveTransaction(transaction);
  Future<void> delete(int id) => _database.deleteTransaction(id);
}
