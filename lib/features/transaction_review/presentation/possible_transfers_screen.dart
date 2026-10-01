import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../accounts/providers/account_provider.dart';
import '../../transactions/domain/entities/transfer_candidate.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/providers/transfer_candidate_provider.dart';

class PossibleTransfersScreen extends ConsumerWidget {
  const PossibleTransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transferCandidateListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Possible transfers')),
      body: state.when(
        loading: () => const AppLoadingList(),
        error: (_, __) => AppErrorState(
          title: 'Could not load possible transfers',
          message: 'Please try again.',
          onRetry: () => ref.read(transferCandidateListProvider.notifier).refresh(),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                icon: Icons.compare_arrows_rounded,
                title: 'No possible transfers',
                message: 'Potential movements between your accounts will appear here.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: items.map((item) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.compare_arrows_rounded),
                    title: Text(MoneyFormatter.format(item.outgoing.amountMinor)),
                    subtitle: Text('${item.confidence} evidence · review needed'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PossibleTransferDetailsScreen(candidate: item),
                    )),
                  ),
                )).toList(),
              ),
      ),
    );
  }
}

class PossibleTransferDetailsScreen extends ConsumerWidget {
  const PossibleTransferDetailsScreen({super.key, required this.candidate});
  final TransferCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountListProvider).valueOrNull ?? const [];
    String account(int id) => accounts.where((item) => item.id == id).firstOrNull?.name ?? 'Account';
    Widget side(String label, String name, String sign, DateTime date, String classification) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6), Text(name, style: Theme.of(context).textTheme.titleMedium),
          Text('$sign${MoneyFormatter.format(candidate.outgoing.amountMinor)}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6), Text('Transaction time: ${MaterialLocalizations.of(context).formatMediumDate(date)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}'),
          Text('Original classification: $classification'),
        ]),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Possible internal transfer')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Flowly found matching normalized transactions. Review them before changing your accounting.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        side('FROM', account(candidate.outgoing.accountId), '-', candidate.outgoing.date, candidate.outgoing.type.name),
        const Icon(Icons.south_rounded),
        side('TO', account(candidate.incoming.accountId), '+', candidate.incoming.date, candidate.incoming.type.name),
        const SizedBox(height: 12),
        ListTile(title: const Text('Confidence'), subtitle: Text(candidate.confidence)),
        const ListTile(title: Text('Why this is suggested'), subtitle: Text('Opposite directions, the same amount and currency, different mapped accounts, and compatible time evidence. Raw SMS content is never shown.')),
        const SizedBox(height: 16),
        FilledButton(onPressed: () async {
          await ref.read(transactionListProvider.notifier).linkTransfer(outgoingTransactionId: candidate.outgoing.id!, incomingTransactionId: candidate.incoming.id!);
          await ref.read(transferCandidateListProvider.notifier).refresh();
          if (context.mounted) Navigator.pop(context);
        }, child: const Text('Confirm as Transfer')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () async {
          await ref.read(transferCandidateListProvider.notifier).reject(candidate.id);
          if (context.mounted) Navigator.pop(context);
        }, child: const Text('Not a Transfer')),
      ]),
    );
  }
}
