import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../backup/data/backup_service.dart';
import 'export_workflow_screen.dart';

class BackupConfigurationScreen extends StatefulWidget {
  const BackupConfigurationScreen({super.key});

  @override
  State<BackupConfigurationScreen> createState() =>
      _BackupConfigurationScreenState();
}

class _BackupConfigurationScreenState
    extends State<BackupConfigurationScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create secure backup')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            Icons.enhanced_encryption_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Protect your financial data',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your backup contains the local financial database and supported settings. It will be encrypted before the system save picker opens.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('AES-256-GCM encryption'),
            subtitle: Text('The file is authenticated so tampering is detected.'),
          ),
          const ListTile(
            leading: Icon(Icons.password_outlined),
            title: Text('Independent password'),
            subtitle: Text('Your app PIN is not used or stored in the backup.'),
          ),
          const ListTile(
            leading: Icon(Icons.warning_amber_rounded),
            title: Text('Keep the password safe'),
            subtitle: Text(
              'SpenFlo cannot recover the backup if its password is forgotten.',
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(20),
      child: FilledButton.icon(
        onPressed: _busy ? null : _create,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_alt_outlined),
        label: Text(_busy ? 'Encrypting…' : 'Set password and save'),
      ),
    ),
  );

  Future<void> _create() async {
    var password = await showSecurePasswordDialog(
      context,
      title: 'Backup password',
      message:
          'Use at least 10 characters. This is separate from your SpenFlo PIN and cannot be recovered.',
    );
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await BackupService(
        AppDatabase.instance,
      ).createEncrypted(password);
      password = null;
      final stamp = DateTime.now().toUtc().toIso8601String().split('T').first;
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save encrypted SpenFlo backup',
        fileName: 'spenflo-backup-$stamp.spenflo',
        type: FileType.custom,
        allowedExtensions: const ['spenflo'],
        bytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == null ? 'Backup save cancelled.' : 'Backup saved securely.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $error')));
      }
    } finally {
      password = null;
      if (mounted) setState(() => _busy = false);
    }
  }
}
