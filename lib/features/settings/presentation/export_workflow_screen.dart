import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../accounts/providers/account_provider.dart';
import '../../backup/data/secure_container_service.dart';
import '../../categories/providers/category_provider.dart';
import '../../export/data/export_service.dart';
import '../../transactions/domain/entities/transaction.dart';

class ExportSetupScreen extends ConsumerStatefulWidget {
  const ExportSetupScreen({super.key});

  @override
  ConsumerState<ExportSetupScreen> createState() => _ExportSetupScreenState();
}

class _ExportSetupScreenState extends ConsumerState<ExportSetupScreen> {
  ExportFormat _format = ExportFormat.pdf;
  DateTimeRange? _range;
  int? _accountId;
  String? _category;
  TransactionType? _type;
  bool _protect = false;
  bool _busy = false;
  PreparedExport? _prepared;

  ExportFilter get _filter => ExportFilter(
    start: _range?.start,
    end: _range?.end,
    accountId: _accountId,
    category: _category,
    type: _type,
  );

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountListProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoryListProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Export report')),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'Report configuration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SegmentedButton<ExportFormat>(
                            segments: ExportFormat.values
                                .map(
                                  (format) => ButtonSegment(
                                    value: format,
                                    label: Text(format.label),
                                    icon: Icon(switch (format) {
                                      ExportFormat.csv =>
                                        Icons.table_chart_outlined,
                                      ExportFormat.excel =>
                                        Icons.grid_on_outlined,
                                      ExportFormat.pdf =>
                                        Icons.picture_as_pdf_outlined,
                                    }),
                                  ),
                                )
                                .toList(),
                            selected: {_format},
                            onSelectionChanged: _busy
                                ? null
                                : (value) =>
                                      _change(() => _format = value.single),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.date_range_outlined),
                            title: const Text('Reporting period'),
                            subtitle: Text(
                              _range == null
                                  ? 'All dates'
                                  : '${DateFormat.yMMMd().format(_range!.start)} – ${DateFormat.yMMMd().format(_range!.end)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _busy ? null : _pickRange,
                          ),
                          DropdownButtonFormField<int?>(
                            initialValue: _accountId,
                            decoration: const InputDecoration(
                              labelText: 'Account',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All accounts'),
                              ),
                              ...accounts.map(
                                (account) => DropdownMenuItem(
                                  value: account.id,
                                  child: Text(account.name),
                                ),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => _change(() => _accountId = value),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All categories'),
                              ),
                              ...categories.map(
                                (category) => DropdownMenuItem(
                                  value: category.name,
                                  child: Text(category.name),
                                ),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => _change(() => _category = value),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<TransactionType?>(
                            initialValue: _type,
                            decoration: const InputDecoration(
                              labelText: 'Transaction type',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('All types'),
                              ),
                              DropdownMenuItem(
                                value: TransactionType.income,
                                child: Text('Income'),
                              ),
                              DropdownMenuItem(
                                value: TransactionType.expense,
                                child: Text('Expense'),
                              ),
                              DropdownMenuItem(
                                value: TransactionType.transfer,
                                child: Text('Transfer'),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => _change(() => _type = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile(
                      value: _protect,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _protect = value),
                      secondary: const Icon(Icons.lock_outline),
                      title: const Text('Protect saved/shared file'),
                      subtitle: Text(
                        _protect
                            ? 'Save and Share create an encrypted .spenflo package.'
                            : 'The exported file can be opened by anyone who can access it.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Available actions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _previewPrint,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Preview / Print'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_alt_outlined),
                    label: Text(
                      _protect ? 'Save encrypted export' : 'Save to device',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(_protect ? 'Share encrypted export' : 'Share'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Preview / Print opens Android’s system print interface. For CSV and Excel, it shows a printable PDF representation without changing the file saved or shared.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _change(VoidCallback update) {
    setState(() {
      update();
      _prepared = null;
    });
  }

  Future<void> _pickRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (selected != null && mounted) _change(() => _range = selected);
  }

  Future<PreparedExport> _ensurePrepared() async {
    final existing = _prepared;
    if (existing != null) return existing;
    final prepared = await ExportService(AppDatabase.instance)
        .prepare(_format, _filter);
    _prepared = prepared;
    return prepared;
  }

  Future<void> _previewPrint() async {
    if (_protect && !await _confirmPrintablePreview()) return;
    await _run(() async {
      final prepared = await _ensurePrepared();
      await Printing.layoutPdf(
        name: 'spenflo-printable-report.pdf',
        dynamicLayout: false,
        onLayout: (_) async => prepared.printablePdfBytes,
      );
      // Android does not reliably report whether the user printed, saved, or
      // dismissed the system interface, so no completion message is shown.
    }, failurePrefix: 'Could not open Print Preview');
  }

  Future<bool> _confirmPrintablePreview() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.print_outlined),
            title: const Text('Printable preview'),
            content: const Text(
              'Android Print Preview requires a readable PDF representation. Your Save and Share actions will still use the password-protected .spenflo package.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Open Print Preview'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    await _run(() async {
      final output = await _output();
      if (output == null) return;
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save SpenFlo report',
        fileName: output.name,
        type: FileType.custom,
        allowedExtensions: [output.name.split('.').last],
        bytes: output.bytes,
      );
      if (!mounted || result == null) return;
      _message('Export saved successfully.');
    }, failurePrefix: 'Save failed');
  }

  Future<void> _share() async {
    await _run(() async {
      final output = await _output();
      if (output == null) return;
      final directory = await getTemporaryDirectory();
      await _removeStaleShareFiles(directory);
      final temporary = File(
        p.join(
          directory.path,
          'spenflo-share-${DateTime.now().microsecondsSinceEpoch}-${output.name}',
        ),
      );
      try {
        await temporary.writeAsBytes(output.bytes, flush: true);
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(temporary.path, mimeType: output.mimeType)],
            fileNameOverrides: [output.name],
          ),
        );
        if (result.status == ShareResultStatus.dismissed) {
          await _deleteIfPresent(temporary);
          return;
        }
        unawaited(
          Future<void>.delayed(
            const Duration(minutes: 10),
            () => _deleteIfPresent(temporary),
          ),
        );
        if (!mounted) return;
        if (result.status == ShareResultStatus.success) {
          _message('A share target was selected.');
        } else {
          _message('Sharing result is unavailable on this device.');
        }
      } catch (_) {
        await _deleteIfPresent(temporary);
        rethrow;
      }
    }, failurePrefix: 'Could not open sharing');
  }

  Future<_ExportOutput?> _output() async {
    final prepared = await _ensurePrepared();
    if (!_protect) {
      return _ExportOutput(
        name: prepared.filename,
        mimeType: prepared.format.mimeType,
        bytes: prepared.bytes,
      );
    }
    if (!mounted) return null;
    var password = await showSecurePasswordDialog(
      context,
      title: 'Export password',
      message: 'Use at least 10 characters. This password cannot be recovered if forgotten.',
    );
    if (password == null) return null;
    final encrypted = await SecureContainerService().encrypt(
      bytes: prepared.bytes,
      password: password,
      purpose: 'export',
      originalFilename: prepared.filename,
    );
    password = null;
    return _ExportOutput(
      name: '${prepared.filename}.spenflo',
      mimeType: 'application/octet-stream',
      bytes: encrypted,
    );
  }

  Future<void> _run(
    Future<void> Function() operation, {
    required String failurePrefix,
  }) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) _message('$failurePrefix: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeStaleShareFiles(Directory directory) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    await for (final entity in directory.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('spenflo-share-') &&
          (await entity.lastModified()).isBefore(cutoff)) {
        await _deleteIfPresent(entity);
      }
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cache cleanup must not convert a completed share into a failure.
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExportOutput {
  const _ExportOutput({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

Future<String?> showSecurePasswordDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  var obscure = true;
  String? error;
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () => update(() => obscure = !obscure),
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  errorText: error,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (password.text.length < 10) {
                update(() => error = 'Use at least 10 characters.');
              } else if (password.text != confirmation.text) {
                update(() => error = 'Passwords do not match.');
              } else {
                Navigator.pop(dialogContext, password.text);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
  password.clear();
  confirmation.clear();
  password.dispose();
  confirmation.dispose();
  return result;
}
