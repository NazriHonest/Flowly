import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../domain/entities/transaction.dart';
import '../domain/services/transfer_reconciliation_service.dart';
import '../providers/transaction_provider.dart';
import 'transaction_form_screen.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../accounts/providers/account_provider.dart';
import '../../../core/theme/app_colors.dart';

class TransactionDetailsScreen extends ConsumerWidget {
  const TransactionDetailsScreen({super.key, required this.transaction});
  final Transaction transaction;
  @override
  Widget build(BuildContext c, WidgetRef r) => Scaffold(
    appBar: AppBar(
      title: const Text('Transaction'),
      actions: [
        if (transaction.type == TransactionType.expense &&
            transaction.id != null)
          IconButton(
            tooltip: 'Mark as transfer',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: () => _showTransferCandidates(c, r, transaction),
          ),
        if (transaction.type == TransactionType.transfer &&
            transaction.id != null)
          IconButton(
            tooltip: 'Unlink transfer',
            icon: const Icon(Icons.link_off_rounded),
            onPressed: () async {
              final approved = await showFlowlyConfirmation(
                c,
                title: 'Unlink transfer?',
                message: 'The original incoming and outgoing SMS records will be restored.',
                confirmLabel: 'Unlink transfer',
              );
              if (!approved) return;
              try {
                await r
                    .read(transactionListProvider.notifier)
                    .unlinkTransfer(transaction.id!);
                if (c.mounted) Navigator.pop(c);
              } on StateError {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This transfer is not linked to an SMS pair.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        IconButton(
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(
              builder: (_) => TransactionFormScreen(transaction: transaction),
            ),
          ),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Delete transaction',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final approved = await showFlowlyConfirmation(
              c,
              title: 'Delete transaction?',
              message: 'Totals, budgets, and analytics will update.',
              confirmLabel: 'Delete transaction',
            );
            if (approved && transaction.id != null) {
              await r
                  .read(transactionListProvider.notifier)
                  .delete(transaction.id!);
              if (c.mounted) Navigator.pop(c);
            }
          },
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _TransactionHero(transaction: transaction),
        const SizedBox(height: 20),
        FlowlySection(
          title: 'Transaction information',
          children: [
            ListTile(
              title: const Text('Account'),
              trailing: Text(
                (r
                        .watch(accountListProvider)
                        .valueOrNull
                        ?.where((a) => a.id == transaction.accountId)
                        .firstOrNull
                        ?.name) ??
                    'Account',
              ),
            ),
            ListTile(
              title: const Text('Transaction time'),
              trailing: Text(_formatDateTime(c, transaction.date)),
            ),
            ListTile(
              title: const Text('Flowly created at'),
              trailing: Text(
                transaction.createdAt == null
                    ? 'Unavailable'
                    : _formatDateTime(c, transaction.createdAt!),
              ),
            ),
            ListTile(
              title: const Text('Category'),
              trailing: Text(transaction.category),
            ),
            ListTile(
              title: const Text('Type'),
              trailing: Text(transaction.type.name),
            ),
            ListTile(
              title: const Text('Source'),
              trailing: Text(transaction.source.name),
            ),
            ListTile(
              title: const Text('Status'),
              trailing: Text(transaction.status.name),
            ),
            if (transaction.notes.isNotEmpty)
              ListTile(
                title: const Text('Notes'),
                subtitle: Text(transaction.notes),
              ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _showTransferCandidates(
  BuildContext context,
  WidgetRef ref,
  Transaction outgoing,
) async {
  final transactions =
      ref.read(transactionListProvider).valueOrNull ?? const <Transaction>[];
  final accounts = ref.read(accountListProvider).valueOrNull ?? const [];
  final currencies = {
    for (final account in accounts) account.id as int: account.currency as String,
  };
  final outgoingCurrency = currencies[outgoing.accountId];
  if (outgoingCurrency == null) return;
  final candidates = TransferReconciliationService().candidatesFor(
    outgoing: outgoing,
    transactions: transactions,
    outgoingCurrency: outgoingCurrency,
    currencyForAccount: (id) => currencies[id] ?? '',
  );
  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No compatible incoming transaction found.'),
      ),
    );
    return;
  }
  final selected = await showModalBottomSheet<TransferMatch>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text('Mark as transfer'),
            subtitle: Text('Choose the matching incoming transaction.'),
          ),
          ...candidates.map((match) {
            final candidate = match.incoming;
            final account = accounts
                .where((item) => item.id == candidate.accountId)
                .firstOrNull;
            return ListTile(
              leading: const Icon(Icons.call_received_rounded),
              title: Text(account?.name ?? 'Destination account'),
              subtitle: Text(
                '${candidate.title} · ${_formatDateTime(sheetContext, candidate.date)}',
              ),
              trailing: Text(MoneyFormatter.format(candidate.amountMinor)),
              onTap: () => Navigator.pop(sheetContext, match),
            );
          }),
        ],
      ),
    ),
  );
  if (selected == null ||
      outgoing.id == null ||
      selected.incoming.id == null ||
      !context.mounted) {
    return;
  }
  final approved = await showFlowlyConfirmation(
    context,
    title: 'Confirm transfer link?',
    message: 'This will count the movement once as a transfer and retain both normalized SMS records.',
    confirmLabel: 'Confirm transfer',
  );
  if (!approved) return;
  await ref
      .read(transactionListProvider.notifier)
      .linkTransfer(
        outgoingTransactionId: outgoing.id!,
        incomingTransactionId: selected.incoming.id!,
      );
  if (context.mounted) Navigator.pop(context);
}

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date, $time';
}

class _TransactionHero extends StatelessWidget {
  const _TransactionHero({required this.transaction});
  final Transaction transaction;
  @override
  Widget build(BuildContext context) {
    final color = switch (transaction.type) {
      TransactionType.income => AppColors.income,
      TransactionType.transfer => AppColors.transfer,
      TransactionType.expense => AppColors.expense,
    };
    final icon = switch (transaction.type) {
      TransactionType.income => Icons.south_west_rounded,
      TransactionType.transfer => Icons.swap_horiz_rounded,
      TransactionType.expense => Icons.north_east_rounded,
    };
    return FlowlySurface(
      child: Column(
        children: [
          FlowlyIcon(icon: icon, color: color, size: 64),
          const SizedBox(height: 12),
          Text(
            transaction.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            transaction.category,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            MoneyFormatter.format(transaction.amountMinor),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
