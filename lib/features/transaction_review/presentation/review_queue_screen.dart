import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/providers/transfer_candidate_provider.dart';
import 'possible_transfers_screen.dart';
import 'pending_sms_transfers_screen.dart';

class ReviewQueueScreen extends ConsumerWidget {
  const ReviewQueueScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionListProvider);
    final possibleTransfers =
        ref.watch(transferCandidateListProvider).valueOrNull ?? const [];
    final pendingSmsTransfers =
        ref.watch(pendingSmsTransferListProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: state.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(
          title: 'Couldn’t load reviews',
          message: '$error',
          onRetry: () => ref.invalidate(transactionListProvider),
        ),
        data: (items) {
          final review = items
              .where((item) => item.status == ReviewStatus.needsReview)
              .toList();
          if (review.isEmpty &&
              possibleTransfers.isEmpty &&
              pendingSmsTransfers.isEmpty) {
            return const AppEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'You’re all caught up',
              message:
                  'Transactions that need your confirmation will appear here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              if (possibleTransfers.isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.compare_arrows_rounded),
                    title: const Text('Possible transfers'),
                    subtitle: Text(
                      '${possibleTransfers.length} movement${possibleTransfers.length == 1 ? '' : 's'} between your accounts need review.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PossibleTransfersScreen(),
                      ),
                    ),
                  ),
                ),
              if (pendingSmsTransfers.isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_outlined),
                    title: const Text('Possible account transfers'),
                    subtitle: Text(
                      '${pendingSmsTransfers.length} transfer${pendingSmsTransfers.length == 1 ? '' : 's'} need a linked account.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PendingSmsTransfersScreen(),
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_outlined,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${review.length} transaction${review.length == 1 ? '' : 's'} need your confirmation.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              ...review.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.warning.withValues(alpha: .14),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.warning,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${item.category} • ${MaterialLocalizations.of(context).formatMediumDate(item.date)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          MoneyFormatter.signed(
                            item.amountMinor,
                            negative: item.type == TransactionType.expense,
                          ),
                          style: TextStyle(
                            color: item.type == TransactionType.expense
                                ? AppColors.expense
                                : AppColors.income,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Review',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewDetailsScreen(transaction: item),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ReviewDetailsScreen extends ConsumerWidget {
  const ReviewDetailsScreen({super.key, required this.transaction});
  final Transaction transaction;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        (ref.watch(transactionListProvider).valueOrNull ??
                const <Transaction>[])
            .where((item) => item.id == transaction.id)
            .firstOrNull;
    if (current == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.task_alt_rounded,
          title: 'Review complete',
          message: 'This transaction is no longer awaiting review.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review transaction')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.manage_search_rounded,
                  color: AppColors.warning,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  current.title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  MoneyFormatter.signed(
                    current.amountMinor,
                    negative: current.type == TransactionType.expense,
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Amount'),
            subtitle: Text(MoneyFormatter.format(current.amountMinor)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Category'),
            subtitle: Text(current.category),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Type'),
            subtitle: Text(current.type.name),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Confirm transaction'),
            onPressed: () =>
                _setStatus(context, ref, current, ReviewStatus.confirmed),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit before confirming'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionFormScreen(transaction: current),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.expense),
            icon: const Icon(Icons.block_outlined),
            label: const Text('Ignore transaction'),
            onPressed: () =>
                _setStatus(context, ref, current, ReviewStatus.ignored),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    Transaction current,
    ReviewStatus status,
  ) async {
    await ref
        .read(transactionListProvider.notifier)
        .save(
          Transaction(
            id: current.id,
            amountMinor: current.amountMinor,
            type: current.type,
            title: current.title,
            category: current.category,
            accountId: current.accountId,
            destinationAccountId: current.destinationAccountId,
            date: current.date,
            source: current.source,
            status: status,
            notes: current.notes,
            providerTransactionAt: current.providerTransactionAt,
            smsReceivedAt: current.smsReceivedAt,
            createdAt: current.createdAt,
          ),
        );
    if (context.mounted) Navigator.pop(context);
  }
}
