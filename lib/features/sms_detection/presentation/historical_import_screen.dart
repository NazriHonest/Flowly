import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../data/historical_import_processor.dart';
import '../data/historical_sms_bridge.dart';
import '../data/sms_permission_bridge.dart';
import '../domain/services/financial_sms_parser_registry.dart';
import '../domain/services/financial_sms_pipeline.dart';
import '../parsers/evc_plus_parser.dart';
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
          selected = {
            for (var i = 0; i < result.items.length; i++)
              if (!result.items[i].duplicate) i,
          };
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
                _Count('Generic', result.generic),
                _Count('Duplicates', result.duplicates),
                _Count('Confirmed', result.confirmed),
                _Count('Needs review', result.needsReview),
                _Count('Ignored/unrecognized', result.ignored),
                _Count('Rejected', result.rejected),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: result.items.length,
              itemBuilder: (context, index) {
                final item = result.items[index];
                return CheckboxListTile(
                  value: selected.contains(index),
                  enabled: !item.duplicate,
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      selected.add(index);
                    } else {
                      selected.remove(index);
                    }
                  }),
                  title: Text(item.provider),
                  subtitle: Text(
                    '${item.transaction.type == TransactionType.income ? 'Income' : 'Expense'} · '
                    '${_dateTime(item.transaction.date)}\n'
                    'Account: ${item.accountName} · '
                    '${item.transaction.status == ReviewStatus.confirmed ? 'Confirmed' : 'Needs review'}'
                    '${item.duplicate ? ' · Duplicate' : ''}',
                  ),
                  isThreeLine: true,
                  secondary: Text(
                    '${item.transaction.type == TransactionType.income ? '+' : '-'}${MoneyFormatter.format(item.transaction.amountMinor, code: item.currency)}',
                    textAlign: TextAlign.end,
                  ),
                );
              },
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

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
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
