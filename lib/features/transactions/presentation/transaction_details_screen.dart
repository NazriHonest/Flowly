import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../accounts/providers/account_provider.dart';
import '../domain/entities/transaction.dart';
import '../domain/services/transfer_reconciliation_service.dart';
import '../providers/transaction_provider.dart';
import '../providers/transfer_candidate_provider.dart';
import 'transaction_form_screen.dart';
import 'transaction_presentation.dart';

class TransactionDetailsScreen extends ConsumerWidget {
  const TransactionDetailsScreen({super.key, required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountListProvider).valueOrNull ?? const [];

    final accountNames = {
      for (final account in accounts) account.id: account.name,
    };

    final sourceAccountName = accountNames[transaction.accountId] ?? 'Account';

    final destinationAccountName =
        accountNames[transaction.destinationAccountId] ?? 'Account';

    final canUnlink =
        transaction.type == TransactionType.transfer &&
        transaction.id != null &&
        ref.watch(reconciledTransferProvider(transaction.id!)).valueOrNull ==
            true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction details'),
        actions: [
          IconButton(
            tooltip: 'Edit transaction',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionFormScreen(transaction: transaction),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<_TransactionMenuAction>(
            tooltip: 'More options',
            onSelected: (action) async {
              switch (action) {
                case _TransactionMenuAction.markAsTransfer:
                  await _showTransferCandidates(context, ref, transaction);
                  break;

                case _TransactionMenuAction.unlinkTransfer:
                  await _unlinkTransfer(context, ref, transaction);
                  break;

                case _TransactionMenuAction.delete:
                  await _deleteTransaction(context, ref, transaction);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (transaction.type == TransactionType.expense &&
                  transaction.id != null)
                const PopupMenuItem(
                  value: _TransactionMenuAction.markAsTransfer,
                  child: _MenuItemContent(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Mark as transfer',
                  ),
                ),
              if (canUnlink)
                const PopupMenuItem(
                  value: _TransactionMenuAction.unlinkTransfer,
                  child: _MenuItemContent(
                    icon: Icons.link_off_rounded,
                    label: 'Unlink transfer',
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _TransactionMenuAction.delete,
                child: _MenuItemContent(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete transaction',
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _TransactionHero(transaction: transaction),
            const SizedBox(height: 24),

            if (transaction.type == TransactionType.transfer) ...[
              const _SectionHeader(
                title: 'Transfer',
                subtitle: 'Movement between your accounts',
              ),
              const SizedBox(height: 10),
              _TransferRouteCard(
                sourceAccountName: sourceAccountName,
                destinationAccountName: destinationAccountName,
                amountMinor: transaction.amountMinor,
              ),
            ] else ...[
              const _SectionHeader(
                title: 'Account',
                subtitle: 'Account used for this transaction',
              ),
              const SizedBox(height: 10),
              _AccountCard(
                accountName: sourceAccountName,
                transactionType: transaction.type,
              ),
            ],

            const SizedBox(height: 24),

            const _SectionHeader(
              title: 'Transaction information',
              subtitle: 'Date, category and record information',
            ),
            const SizedBox(height: 10),

            _InformationCard(
              children: [
                _InformationRow(
                  icon: Icons.event_outlined,
                  label: 'Transaction time',
                  value: _formatDateTime(context, transaction.date),
                ),
                const _InformationDivider(),
                _InformationRow(
                  icon: Icons.schedule_rounded,
                  label: 'Added to Flowly',
                  value: transaction.createdAt == null
                      ? 'Unavailable'
                      : _formatDateTime(context, transaction.createdAt!),
                ),
                const _InformationDivider(),
                _InformationRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: transaction.category,
                ),
              ],
            ),

            const SizedBox(height: 24),

            const _SectionHeader(
              title: 'Classification',
              subtitle: 'How this transaction is recorded',
            ),
            const SizedBox(height: 10),

            _ClassificationCard(transaction: transaction),

            if (transaction.notes.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Notes',
                subtitle: 'Additional transaction information',
              ),
              const SizedBox(height: 10),
              _NotesCard(notes: transaction.notes),
            ],

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TransactionFormScreen(transaction: transaction),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TransactionMenuAction { markAsTransfer, unlinkTransfer, delete }

class _MenuItemContent extends StatelessWidget {
  const _MenuItemContent({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, size: 20, color: effectiveColor),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: effectiveColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TransactionHero extends StatelessWidget {
  const _TransactionHero({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _transactionColor(transaction.type);
    final icon = _transactionIcon(transaction.type);

    final amountPrefix = switch (transaction.type) {
      TransactionType.income => '+',
      TransactionType.expense => '−',
      TransactionType.transfer => '',
    };

    return FlowlySurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),

            Text(
              transaction.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              transaction.category,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 14),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$amountPrefix${MoneyFormatter.format(transaction.amountMinor)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _SemanticBadge(
                  icon: icon,
                  label: _transactionTypeLabel(transaction.type),
                  color: color,
                ),
                _NeutralBadge(
                  icon: _sourceIcon(transaction.source.displayLabel),
                  label: transaction.source.displayLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferRouteCard extends StatelessWidget {
  const _TransferRouteCard({
    required this.sourceAccountName,
    required this.destinationAccountName,
    required this.amountMinor,
  });

  final String sourceAccountName;
  final String destinationAccountName;
  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FlowlySurface(
      child: Column(
        children: [
          _TransferAccountRow(
            icon: Icons.call_made_rounded,
            label: 'From',
            accountName: sourceAccountName,
            color: AppColors.expense,
          ),

          Padding(
            padding: const EdgeInsets.only(left: 21, top: 4, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 18,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),

          _TransferAccountRow(
            icon: Icons.call_received_rounded,
            label: 'To',
            accountName: destinationAccountName,
            color: AppColors.income,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: colorScheme.outlineVariant),
          ),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Transfer amount',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                MoneyFormatter.format(amountMinor),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.transfer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransferAccountRow extends StatelessWidget {
  const _TransferAccountRow({
    required this.icon,
    required this.label,
    required this.accountName,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String accountName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 21, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                accountName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.accountName,
    required this.transactionType,
  });

  final String accountName;
  final TransactionType transactionType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _transactionColor(transactionType);

    return FlowlySurface(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: color,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  accountName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FlowlySurface(child: Column(children: children));
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationDivider extends StatelessWidget {
  const _InformationDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 50),
      child: Divider(
        height: 20,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final typeColor = _transactionColor(transaction.type);

    return FlowlySurface(
      child: Column(
        children: [
          _ClassificationRow(
            icon: _transactionIcon(transaction.type),
            label: 'Type',
            child: _SemanticBadge(
              label: _transactionTypeLabel(transaction.type),
              color: typeColor,
            ),
          ),
          const SizedBox(height: 16),
          _ClassificationRow(
            icon: _sourceIcon(transaction.source.displayLabel),
            label: 'Source',
            child: _NeutralBadge(label: transaction.source.displayLabel),
          ),
          const SizedBox(height: 16),
          _ClassificationRow(
            icon: Icons.verified_outlined,
            label: 'Status',
            child: _NeutralBadge(
              label: _displayEnumName(transaction.status.name),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassificationRow extends StatelessWidget {
  const _ClassificationRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        child,
      ],
    );
  }
}

class _SemanticBadge extends StatelessWidget {
  const _SemanticBadge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NeutralBadge extends StatelessWidget {
  const _NeutralBadge({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FlowlySurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notes_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notes,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _unlinkTransfer(
  BuildContext context,
  WidgetRef ref,
  Transaction transaction,
) async {
  if (transaction.id == null) return;

  final approved = await showFlowlyConfirmation(
    context,
    title: 'Unlink transfer?',
    message: 'The original incoming and outgoing SMS records will be restored.',
    confirmLabel: 'Unlink transfer',
  );

  if (!approved) return;

  try {
    await ref
        .read(transactionListProvider.notifier)
        .unlinkTransfer(transaction.id!);

    await ref.read(pendingSmsTransferListProvider.notifier).refresh();

    if (context.mounted) {
      Navigator.pop(context);
    }
  } on StateError {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This transfer is not linked to an SMS pair.'),
        ),
      );
    }
  }
}

Future<void> _deleteTransaction(
  BuildContext context,
  WidgetRef ref,
  Transaction transaction,
) async {
  final approved = await showFlowlyConfirmation(
    context,
    title: 'Delete transaction?',
    message: 'Totals, budgets, and analytics will update.',
    confirmLabel: 'Delete transaction',
  );

  if (!approved || transaction.id == null) return;

  await ref.read(transactionListProvider.notifier).delete(transaction.id!);

  if (context.mounted) {
    Navigator.pop(context);
  }
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
    for (final account in accounts)
      // ignore: unnecessary_cast
      account.id as int: account.currency as String,
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
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mark as transfer',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the matching incoming transaction.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final match = candidates[index];
                      final candidate = match.incoming;

                      final account = accounts
                          .where((item) => item.id == candidate.accountId)
                          .firstOrNull;

                      return Material(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(sheetContext, match),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.income.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.call_received_rounded,
                                    size: 21,
                                    color: AppColors.income,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account?.name ?? 'Destination account',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        candidate.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDateTime(
                                          sheetContext,
                                          candidate.date,
                                        ),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  MoneyFormatter.format(candidate.amountMinor),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppColors.income,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
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

  if (context.mounted) {
    Navigator.pop(context);
  }
}

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();

  final date = MaterialLocalizations.of(context).formatMediumDate(local);

  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));

  return '$date, $time';
}

Color _transactionColor(TransactionType type) {
  return switch (type) {
    TransactionType.income => AppColors.income,
    TransactionType.expense => AppColors.expense,
    TransactionType.transfer => AppColors.transfer,
  };
}

IconData _transactionIcon(TransactionType type) {
  return switch (type) {
    TransactionType.income => Icons.south_west_rounded,
    TransactionType.expense => Icons.north_east_rounded,
    TransactionType.transfer => Icons.swap_horiz_rounded,
  };
}

String _transactionTypeLabel(TransactionType type) {
  return switch (type) {
    TransactionType.income => 'Income',
    TransactionType.expense => 'Expense',
    TransactionType.transfer => 'Transfer',
  };
}

IconData _sourceIcon(String source) {
  return switch (source.toLowerCase()) {
    'auto' => Icons.bolt_rounded,
    'imported' => Icons.download_rounded,
    'manual' => Icons.touch_app_outlined,
    'recurring' => Icons.repeat_rounded,
    _ => Icons.receipt_long_outlined,
  };
}

String _displayEnumName(String value) {
  if (value.isEmpty) return value;

  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );

  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
