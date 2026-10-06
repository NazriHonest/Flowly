import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../accounts/providers/account_provider.dart';
import '../../sms_detection/domain/entities/sms_transfer_observation.dart';
import '../../sms_detection/domain/entities/transaction_candidate.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/providers/transfer_candidate_provider.dart';

class PendingSmsTransfersScreen extends ConsumerWidget {
  const PendingSmsTransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSmsTransferListProvider);
    final accounts = ref.watch(accountListProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Possible account transfers')),
      body: pending.when(
        loading: () => const AppLoadingList(),
        error: (_, __) => AppErrorState(
          title: 'Could not load transfers',
          message: 'Please try again.',
          onRetry: () =>
              ref.read(pendingSmsTransferListProvider.notifier).refresh(),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                icon: Icons.compare_arrows_rounded,
                title: 'No account selection needed',
                message: 'Unresolved SMS transfers will appear here.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: items.map((item) {
                  final mapped = accounts
                      .where((account) => account.id == item.mappedAccountId)
                      .firstOrNull;
                  final direction =
                      item.direction == TransferObservationDirection.outgoing
                      ? 'From ${mapped?.name ?? 'mapped account'}'
                      : 'To ${mapped?.name ?? 'mapped account'}';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.compare_arrows_rounded),
                      title: Text(
                        MoneyFormatter.format(
                          item.amountMinor,
                          code: item.currency,
                        ),
                      ),
                      subtitle: Text('${item.providerName} · $direction'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'choose') {
                            await _resolve(context, ref, item);
                          } else if (value == 'ignore') {
                            await ref
                                .read(pendingSmsTransferListProvider.notifier)
                                .reject(item.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'choose',
                            child: Text('Choose linked account'),
                          ),
                          PopupMenuItem(
                            value: 'ignore',
                            child: Text('Not a transfer'),
                          ),
                        ],
                      ),
                      onTap: () => _resolve(context, ref, item),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    SmsTransferObservation observation,
  ) async {
    final accounts = ref.read(accountListProvider).valueOrNull ?? const [];
    final mapped = accounts
        .where((account) => account.id == observation.mappedAccountId)
        .firstOrNull;
    final choices = accounts
        .where(
          (account) =>
              account.id != observation.mappedAccountId &&
              account.currency.toUpperCase() == observation.currency,
        )
        .toList();
    final accountId = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Choose linked account'),
              subtitle: Text(
                observation.direction == TransferObservationDirection.outgoing
                    ? 'Money left ${mapped?.name ?? 'the mapped account'}. Where did it go?'
                    : 'Money entered ${mapped?.name ?? 'the mapped account'}. Where did it come from?',
              ),
            ),
            ...choices.map(
              (account) => ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: Text(account.name),
                subtitle: Text(account.type.replaceAll('_', ' ')),
                onTap: () => Navigator.pop(context, account.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (accountId == null || !context.mounted) return;
    await ref
        .read(pendingSmsTransferListProvider.notifier)
        .resolve(observation.id, accountId);
    await ref.read(transactionListProvider.notifier).refresh();
    if (context.mounted) {
      showFlowlySnackBar(context, 'Internal transfer confirmed');
    }
  }
}
