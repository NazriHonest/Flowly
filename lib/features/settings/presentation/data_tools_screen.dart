import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/database/app_database.dart';
import '../../backup/data/backup_service.dart';
import '../../export/data/export_service.dart';
import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../../core/widgets/app_widgets.dart';

class DataToolsScreen extends ConsumerStatefulWidget {
  const DataToolsScreen({super.key});
  @override
  ConsumerState<DataToolsScreen> createState() => _DataToolsScreenState();
}

class _DataToolsScreenState extends ConsumerState<DataToolsScreen> {
  bool busy = false;
  String? completedPath;
  String? operationError;
  ExportFilter filter = const ExportFilter();
  Future<void> run(Future<File> Function() work) async {
    setState(() => busy = true);
    try {
      final file = await work();
      if (mounted) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
        if (mounted) setState(() => completedPath = file.path);
      }
    } catch (e) {
      if (mounted) setState(() => operationError = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final export = ExportService(AppDatabase.instance);
    final backup = BackupService(AppDatabase.instance);
    if (completedPath != null || operationError != null) {
      final success = completedPath != null;
      return Scaffold(
        appBar: AppBar(title: Text(success ? 'Export ready' : 'Operation failed')),
        body: AppEmptyState(
          icon: success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          title: success ? 'Your file is ready' : 'We couldn’t finish that',
          message: success ? 'The file was generated and shared from this device.' : operationError!,
          actionLabel: success ? 'Done' : 'Try again',
          onAction: () => setState(() { completedPath = null; operationError = null; }),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (busy) const LinearProgressIndicator(),
          FlowlySection(title: 'Export', children: [
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export CSV'),
            subtitle: const Text('Normalized transaction data'),
            onTap: busy ? null : () => run(() => export.csv(filter)),
          ),
          ListTile(
            leading: const Icon(Icons.grid_on_outlined),
            title: const Text('Export Excel workbook'),
            subtitle: const Text(
              'Summary, transactions, accounts, categories, budgets and goals',
            ),
            onTap: busy ? null : () => run(() => export.xlsx(filter)),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export PDF report'),
            subtitle: const Text('Financial summary and transactions'),
            onTap: busy ? null : () => run(() => export.pdf(filter)),
          ),
          ListTile(
            leading: const Icon(Icons.filter_alt_outlined),
            title: const Text('Export filters'),
            subtitle: Text(_filterSummary()),
            onTap: busy ? null : _editFilter,
          ),
          ]),
          FlowlySection(title: 'Backup', children: [
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Create backup'),
            subtitle: const Text(
              'Versioned local database and settings archive',
            ),
            onTap: busy ? null : () => run(backup.create),
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore backup'),
            subtitle: const Text(
              'Choose a .zip backup to validate and restore',
            ),
            onTap: busy
                ? null
                : () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['zip'],
                    );
                    final path = result?.files.single.path;
                    if (path == null) return;
                    final confirmed = await showFlowlyConfirmation(
                      context,
                      title: 'Restore this backup?',
                      message: 'Flowly validates the selected archive first. Restoring replaces local financial data and saved settings.',
                      confirmLabel: 'Restore',
                    );
                    if (!confirmed || !mounted) return;
                    setState(() => busy = true);
                    try {
                      await backup.restore(File(path));
                      if (!mounted) return;
                      ref.invalidate(accountListProvider);
                      ref.invalidate(categoryListProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Backup restored. Return to a screen to reload its restored data.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
          ),
          ]),
        ],
      ),
    );
  }

  String _filterSummary() {
    final selected = <String>[];
    if (filter.start != null) selected.add('date range');
    if (filter.accountId != null) selected.add('account');
    if (filter.category != null) selected.add('category');
    if (filter.type != null) selected.add(filter.type!.name);
    return selected.isEmpty ? 'All transactions' : selected.join(' • ');
  }

  Future<void> _editFilter() async {
    final accounts = ref.read(accountListProvider).valueOrNull ?? const [];
    final categories = ref.read(categoryListProvider).valueOrNull ?? const [];
    var start = filter.start;
    var end = filter.end;
    var account = filter.accountId;
    var category = filter.category;
    var type = filter.type;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Export filters',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ListTile(
                  title: const Text('Date range'),
                  subtitle: Text(
                    start == null
                        ? 'All dates'
                        : '${start!.toLocal().toString().split(' ').first} – ${end!.toLocal().toString().split(' ').first}',
                  ),
                  onTap: () async {
                    final dates = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: start == null
                          ? null
                          : DateTimeRange(start: start!, end: end ?? start!),
                    );
                    if (dates != null) {
                      update(() {
                        start = dates.start;
                        end = dates.end;
                      });
                    }
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: account,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All accounts'),
                    ),
                    ...accounts.map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ),
                  ],
                  onChanged: (value) => update(() => account = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All categories'),
                    ),
                    ...categories.map(
                      (c) =>
                          DropdownMenuItem(value: c.name, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (value) => update(() => category = value),
                ),
                DropdownButtonFormField<TransactionType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Transaction type',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All types'),
                    ),
                    ...TransactionType.values.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                    ),
                  ],
                  onChanged: (value) => update(() => type = value),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => update(() {
                        start = null;
                        end = null;
                        account = null;
                        category = null;
                        type = null;
                      }),
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        setState(
                          () => filter = ExportFilter(
                            start: start,
                            end: end,
                            accountId: account,
                            category: category,
                            type: type,
                          ),
                        );
                        Navigator.pop(sheet);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
