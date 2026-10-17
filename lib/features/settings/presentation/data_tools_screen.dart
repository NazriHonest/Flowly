import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../accounts/providers/account_provider.dart';
import '../../backup/data/backup_service.dart';
import '../../categories/providers/category_provider.dart';
import '../../security/data/security_service.dart';
import '../../spending_allowance/domain/entities/spending_allowance.dart';
import '../../spending_allowance/providers/spending_allowance_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import 'backup_configuration_screen.dart';
import 'export_workflow_screen.dart';

class DataToolsScreen extends ConsumerStatefulWidget {
  const DataToolsScreen({super.key});

  @override
  ConsumerState<DataToolsScreen> createState() => _DataToolsScreenState();
}

class _DataToolsScreenState extends ConsumerState<DataToolsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Data Tools')),
    body: ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_busy) const LinearProgressIndicator(),
        FlowlySection(
          title: 'Export',
          children: [
            ListTile(
              leading: const Icon(Icons.file_present_outlined),
              title: const Text('Create an export'),
              subtitle: const Text(
                'Configure, preview, then choose Save or Share',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExportSetupScreen(),
                      ),
                    ),
            ),
          ],
        ),
        FlowlySection(
          title: 'Backup',
          children: [
            ListTile(
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: const Text('Create secure backup'),
              subtitle: const Text('Encrypted database and settings package'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BackupConfigurationScreen(),
                      ),
                    ),
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Restore backup'),
              subtitle: const Text(
                'Encrypted .spenflo and legacy .zip backups',
              ),
              onTap: _busy ? null : _restore,
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _restore() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['spenflo', 'zip'],
      withData: true,
    );
    if (picked == null || !mounted) return;
    final selected = picked.files.single;
    Uint8List bytes;
    if (selected.bytes != null) {
      bytes = selected.bytes!;
    } else if (selected.path != null) {
      bytes = await File(selected.path!).readAsBytes();
    } else {
      _message('The selected file could not be read.');
      return;
    }

    final backup = BackupService(AppDatabase.instance);
    setState(() => _busy = true);
    try {
      if (backup.isEncrypted(bytes)) {
        final password = await _requestPassword();
        if (password == null) return;
        bytes = await backup.decryptEncrypted(bytes, password);
      } else {
        await backup.validateBytes(bytes);
        if (!mounted) return;
        final action = await _legacyAction();
        if (action == _LegacyAction.cancel) return;
        if (action == _LegacyAction.convert) {
          await _convertLegacy(backup, bytes);
          return;
        }
      }
      if (!await _reauthenticateIfProtected()) return;
      if (!mounted) return;
      final confirmed = await showFlowlyConfirmation(
        context,
        title: 'Replace local data?',
        message:
            'The validated backup will replace the current local database and supported settings. SpenFlo will roll back if restoration fails.',
        confirmLabel: 'Restore',
      );
      if (!confirmed) return;
      await backup.restoreBytes(bytes);
      ref.invalidate(accountListProvider);
      ref.invalidate(categoryListProvider);
      ref.invalidate(transactionListProvider);
      ref.invalidate(currentAllowanceProvider);
      for (final type in AllowancePeriodType.values) {
        ref.invalidate(allowanceSummaryProvider(type));
      }
      _message('Backup restored successfully.');
    } catch (error) {
      _message('Restore failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convertLegacy(
    BackupService backup,
    Uint8List legacyBytes,
  ) async {
    var password = await showSecurePasswordDialog(
      context,
      title: 'Encrypt legacy backup',
      message:
          'Create a protected copy without changing your current SpenFlo data.',
    );
    if (password == null) return;
    final encrypted = await backup.encryptLegacy(legacyBytes, password);
    password = null;
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save encrypted backup copy',
      fileName: 'spenflo-converted-backup.spenflo',
      type: FileType.custom,
      allowedExtensions: const ['spenflo'],
      bytes: encrypted,
    );
    if (!mounted) return;
    _message(
      result == null
          ? 'Conversion save cancelled. Your data was not changed.'
          : 'Encrypted backup copy saved. Your data was not changed.',
    );
  }

  Future<_LegacyAction> _legacyAction() async {
    return await showDialog<_LegacyAction>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded),
            title: const Text('Unencrypted legacy backup'),
            content: const Text(
              'This older ZIP backup is readable without a password. You can restore it or save a new encrypted copy without changing current data.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _LegacyAction.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _LegacyAction.convert),
                child: const Text('Encrypt copy'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _LegacyAction.restore),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        _LegacyAction.cancel;
  }

  Future<String?> _requestPassword() async {
    final controller = TextEditingController();
    var obscure = true;
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Unlock backup'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'Backup password',
              suffixIcon: IconButton(
                onPressed: () => update(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
    controller.clear();
    controller.dispose();
    return value;
  }

  Future<bool> _reauthenticateIfProtected() async {
    final security = SecurityService();
    if (!await security.enabled) return true;
    if (!mounted) return false;
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 12,
          decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.clear();
    controller.dispose();
    if (pin == null) return false;
    final valid = await security.verifyPin(pin);
    if (!valid) _message('PIN verification failed.');
    return valid;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

enum _LegacyAction { cancel, convert, restore }
