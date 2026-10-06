import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/providers/transfer_candidate_provider.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../data/historical_import_processor.dart';
import '../data/historical_sms_bridge.dart';
import '../data/sms_permission_bridge.dart';
import '../domain/entities/transaction_candidate.dart';
import '../domain/services/financial_sms_parser_registry.dart';
import '../domain/services/financial_sms_pipeline.dart';
import '../parsers/evc_plus_parser.dart';
import '../parsers/agro_bank_parser.dart';
import '../parsers/deeqtoon_parser.dart';
import '../parsers/generic_financial_parser.dart';
import '../parsers/jeeb_parser.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/formatters/money_formatter.dart';

class HistoricalImportScreen extends ConsumerStatefulWidget {
  const HistoricalImportScreen({super.key});
  @override
  ConsumerState<HistoricalImportScreen> createState() =>
      _HistoricalImportScreenState();
}

class _HistoricalImportScreenState
    extends ConsumerState<HistoricalImportScreen> {
  HistoricalImportSummary? summary;
  Set<int> selected = {};
  String? error;
  bool loading = false;
  int? completed;

  HistoricalImportProcessor get processor => HistoricalImportProcessor(
    database: AppDatabase.instance,
    pipeline: FinancialSmsPipeline(
      FinancialSmsParserRegistry([
        EvcPlusParser(),
        JeebParser(),
        DeeqtoonParser(),
        AgroBankParser(),
        GenericFinancialParser(),
      ]),
    ),
  );

  Future<void> _start() async {
    setState(() {
      loading = true;
      error = null;
      summary = null;
      completed = null;
    });
    try {
      final permission = const SmsPermissionBridge();
      if (!await permission.isGranted() && !await permission.request()) {
        if (mounted) setState(() => error = 'permission');
        return;
      }
      final rows = await const HistoricalSmsBridge().read();
      final result = await processor.scan(rows);
      if (mounted) {
        setState(() {
          summary = result;
          selected = {};
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'query');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _commit() async {
    final current = summary!;
    setState(() => loading = true);
    final saved = await processor.commit(selected.map((i) => current.items[i]));
    await ref.read(transactionListProvider.notifier).refresh();
    await ref.read(pendingSmsTransferListProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => loading = false);
    setState(() => completed = saved);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historical import')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Scanning messages on this device…'),
            ],
          ),
        ),
      );
    }
    if (error == 'permission') {
      return _MessageState(
        title: 'SMS permission was not granted',
        detail: 'Historical import needs SMS access only while you explicitly start it. You can still use Flowly manually.',
        action: 'Try again',
        onAction: _start,
      );
    }
    if (error != null) {
      return _MessageState(
        title: 'Could not read messages',
        detail: 'Please try again. No message contents were saved.',
        action: 'Try again',
        onAction: _start,
      );
    }
    if (completed != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historical import')),
        body: AppEmptyState(
          icon: Icons.check_circle_rounded,
          title: 'Import complete',
          message: '$completed transactions were added to your timeline.',
          actionLabel: 'Done',
          onAction: () => Navigator.pop(context),
        ),
      );
    }
    final result = summary;
    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historical SMS import')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FlowlyIcon(icon: Icons.sms_outlined, size: 64),
              const SizedBox(height: 20),
              Text(
                'Import past financial messages',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Flowly scans existing SMS locally using the same financial detector as automatic detection. Raw messages are discarded after processing.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.search),
                  label: const Text('Scan messages'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }
    if (result.scanned == 0 || result.detected == 0) {
      return _MessageState(
        title: 'Nothing to import',
        detail: result.scanned == 0
            ? 'There are no SMS messages available on this device.'
            : 'No recognizable financial messages were found.',
        action: 'Scan again',
        onAction: _start,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review import')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _Count('Scanned', result.scanned),
                _Count('Financial detected', result.detected),
                _Count('EVC Plus', result.evcPlus),
                _Count('JEEB', result.jeeb),
                _Count('DEEQTOON', result.deeqtoon),
                _Count('AGROBANK', result.agroBank),
                _Count('Generic', result.generic),
                _Count('Duplicates', result.duplicates),
                _Count('Confirmed', result.confirmed),
                _Count('Needs review', result.needsReview),
                _Count('Ignored/unrecognized', result.ignored),
                _Count('Rejected', result.rejected),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    selected = {
                      for (var i = 0; i < result.items.length; i++)
                        if (!result.items[i].duplicate) i,
                    };
                  }),
                  child: const Text('Select all'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => setState(selected.clear),
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: result.items.length,
                itemBuilder: (context, index) {
                  final item = result.items[index];
                  return _HistoricalImportTile(
                    item: item,
                    selected: selected.contains(index),
                    onChanged: item.duplicate
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              selected.add(index);
                            } else {
                              selected.remove(index);
                            }
                          }),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: selected.isEmpty ? null : _commit,
            child: Text('Import ${selected.length} selected'),
          ),
        ),
      ),
    );
  }
}

class _HistoricalImportTile extends StatelessWidget {
  const _HistoricalImportTile({
    required this.item,
    required this.selected,
    required this.onChanged,
  });

  final HistoricalImportItem item;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final candidate = item.transferCandidate;
    final isTransfer = candidate != null;
    final isIncoming =
        candidate?.transferDirection == TransferObservationDirection.incoming;
    final counterpart = item.linkedAccountName;
    final direction = !isTransfer
        ? null
        : counterpart == null
        ? 'Bank transfer'
        : isIncoming
        ? '$counterpart  →  ${item.accountName}'
        : '${item.accountName}  →  $counterpart';
    final perspective = !isTransfer
        ? null
        : isIncoming
        ? 'Incoming to ${item.accountName}'
        : 'Outgoing from ${item.accountName}';
    final unresolved = !isTransfer || counterpart != null
        ? null
        : isIncoming
        ? 'Source account required'
        : 'Destination account required';
    final status = item.duplicate
        ? 'Duplicate'
        : item.transaction.status == ReviewStatus.confirmed
        ? 'Confirmed'
        : 'Needs review';
    final local = item.transaction.date.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
    final amountPrefix = isTransfer
        ? ''
        : item.transaction.type == TransactionType.income
        ? '+'
        : '-';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!selected),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: selected, onChanged: onChanged),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$amountPrefix${MoneyFormatter.format(item.transaction.amountMinor, code: item.currency)}',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          item.provider,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isTransfer) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              direction!,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unresolved == null
                            ? 'Bank transfer · $perspective'
                            : 'Bank transfer · $unresolved',
                      ),
                    ] else
                      Text(
                        '${item.transaction.type == TransactionType.income ? 'Income' : 'Expense'} · Account: ${item.accountName}',
                      ),
                    const SizedBox(height: 5),
                    Text('$date · $time'),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: item.duplicate
                            ? colors.onSurfaceVariant
                            : item.transaction.status ==
                                  ReviewStatus.needsReview
                            ? colors.tertiary
                            : colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: colors.surfaceContainerHighest,
      side: BorderSide(color: colors.outlineVariant.withValues(alpha: .65)),
      label: Text(
        '$label: $value',
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    required this.detail,
    required this.action,
    required this.onAction,
  });
  final String title, detail, action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historical import')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(detail, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    ),
  );
}
