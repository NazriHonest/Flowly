import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

class PersistedMerchantRule {
  const PersistedMerchantRule(this.id, this.merchant, this.category);
  final int id;
  final String merchant, category;
}

class MerchantRuleController
    extends StateNotifier<AsyncValue<List<PersistedMerchantRule>>> {
  MerchantRuleController() : super(const AsyncLoading()) {
    refresh();
  }
  Future<void> refresh() async {
    final rows = await AppDatabase.instance.merchantRules();
    state = AsyncData(
      rows
          .map(
            (row) => PersistedMerchantRule(
              row['id'] as int,
              row['normalized_merchant'] as String,
              row['category'] as String,
            ),
          )
          .toList(),
    );
  }

  Future<void> save(String merchant, String category) async {
    await AppDatabase.instance.saveMerchantRule(merchant, category);
    await refresh();
  }

  Future<void> delete(int id) async {
    await AppDatabase.instance.deleteMerchantRule(id);
    await refresh();
  }
}

final merchantRuleListProvider =
    StateNotifierProvider<
      MerchantRuleController,
      AsyncValue<List<PersistedMerchantRule>>
    >((_) => MerchantRuleController());
