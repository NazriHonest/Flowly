import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/category.dart';

class CategoryController extends StateNotifier<AsyncValue<List<Category>>> {
  CategoryController(this._database) : super(const AsyncLoading()) {
    refresh();
  }
  final AppDatabase _database;
  Future<void> refresh() async {
    try {
      state = AsyncData(await _database.categories());
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> save(Category category) async {
    await _database.saveCategory(category);
    await refresh();
  }

  Future<void> archive(int id) async {
    await _database.archiveCategory(id);
    await refresh();
  }
}

final categoryListProvider =
    StateNotifierProvider<CategoryController, AsyncValue<List<Category>>>(
      (ref) => CategoryController(AppDatabase.instance),
    );
