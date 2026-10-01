import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/merchant_rule_provider.dart';

class LearnedRulesScreen extends ConsumerWidget {
  const LearnedRulesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(merchantRuleListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Learned rules')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: rules.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(
          title: 'Couldn’t load learned rules',
          message: 'Please try again.',
          onRetry: () => ref.invalidate(merchantRuleListProvider),
        ),
        data: (items) => items.isEmpty
            ? AppEmptyState(
                icon: Icons.auto_awesome_outlined,
                title: 'No learned rules yet',
                message: 'Flowly can learn a category when you correct an imported transaction.',
                actionLabel: 'Add a rule',
                onAction: () => _edit(context, ref),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: items
                    .map(
                      (rule) => Card(
                        margin: const EdgeInsets.only(bottom: 9),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.secondary.withValues(
                              alpha: .13,
                            ),
                            child: const Icon(
                              Icons.auto_awesome_outlined,
                              color: AppColors.secondary,
                            ),
                          ),
                          title: Text(rule.merchant),
                          subtitle: Text(rule.category),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, ref, rule)), IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.expense), onPressed: () async { if (await showFlowlyConfirmation(context, title: 'Delete learned rule?', message: 'Flowly will stop applying this automatic category.', confirmLabel: 'Delete rule')) await ref.read(merchantRuleListProvider.notifier).delete(rule.id); })]),
                          onTap: () => _edit(context, ref, rule),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    PersistedMerchantRule? rule,
  ]) async {
    final merchant = TextEditingController(text: rule?.merchant);
    final category = TextEditingController(text: rule?.category);
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (dialogContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(dialogContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rule == null ? 'Add learned rule' : 'Edit learned rule',
              style: Theme.of(dialogContext).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: merchant,
              decoration: const InputDecoration(labelText: 'Merchant'),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(dialogContext, (
                  merchant.text,
                  category.text,
                )),
                child: const Text('Save rule'),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.$1.trim().isEmpty || result.$2.trim().isEmpty) {
      return;
    }
    if (rule != null) {
      await ref.read(merchantRuleListProvider.notifier).delete(rule.id);
    }
    await ref
        .read(merchantRuleListProvider.notifier)
        .save(result.$1, result.$2);
  }
}
