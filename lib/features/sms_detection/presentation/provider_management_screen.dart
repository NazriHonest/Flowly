import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../accounts/domain/entities/account.dart';
import '../domain/entities/sms_provider.dart';
import '../../../core/widgets/app_widgets.dart';

class ProviderManagementScreen extends StatefulWidget {
  const ProviderManagementScreen({super.key});
  @override
  State<ProviderManagementScreen> createState() =>
      _ProviderManagementScreenState();
}

class _ProviderManagementScreenState extends State<ProviderManagementScreen> {
  final database = AppDatabase.instance;
  bool loading = true;
  List<SmsProvider> providers = const [];
  List<ProviderAccountMapping> mappings = const [];
  List<Account> accounts = const [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      database.smsProviders(),
      database.providerAccountMappings(),
      database.accounts(),
    ]);
    if (mounted) {
      setState(() {
        providers = values[0] as List<SmsProvider>;
        mappings = values[1] as List<ProviderAccountMapping>;
        accounts = values[2] as List<Account>;
        loading = false;
      });
    }
  }

  Future<void> _add() async {
    final nameController = TextEditingController();
    final aliasesController = TextEditingController();
    final details = await showDialog<(String, List<String>)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add supported provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Provider identity',
                hintText: 'For example EVC Plus or JEEB',
              ),
            ),
            TextField(
              controller: aliasesController,
              decoration: const InputDecoration(
                labelText: 'Sender aliases (one per line)',
                hintText: 'The Android sender address or phone number',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              (
                nameController.text,
                aliasesController.text
                    .split('\n')
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toList(),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (details != null && details.$1.trim().isNotEmpty) {
      await database.saveSmsProvider(
        SmsProvider(name: details.$1, senderAliases: details.$2),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Supported providers')),
    floatingActionButton: FloatingActionButton(
      onPressed: _add,
      child: const Icon(Icons.add),
    ),
    body: loading
        ? const AppLoadingList(count: 4)
        : providers.isEmpty
        ? AppEmptyState(
            icon: Icons.sms_outlined,
            title: 'No providers added',
            message: 'Add only trusted financial message providers, then map them to an account.',
            actionLabel: 'Add provider',
            onAction: _add,
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
            children: [
              const _ProviderIntro(),
              const SizedBox(height: 14),
              ...providers.map((provider) {
              final linked = mappings
                  .where((mapping) => mapping.providerId == provider.id)
                  .toList();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                leading: const FlowlyIcon(icon: Icons.account_tree_outlined),
                title: Text(provider.name),
                subtitle: Text(
                  linked.isEmpty
                      ? 'No account mapping'
                      : '${linked.length} account mapping${linked.length == 1 ? '' : 's'}',
                ),
                trailing: Switch(
                  value: provider.enabled,
                  onChanged: (enabled) async {
                    await database.saveSmsProvider(
                      SmsProvider(
                        id: provider.id,
                        name: provider.name,
                        senderAliases: provider.senderAliases,
                        enabled: enabled,
                      ),
                    );
                    await _load();
                  },
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProviderDetailsScreen(provider: provider),
                  ),
                ).then((_) => _load()),
                ),
              );
            }),
            ],
          ),
  );
}

class ProviderDetailsScreen extends StatefulWidget {
  const ProviderDetailsScreen({super.key, required this.provider});
  final SmsProvider provider;
  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  final database = AppDatabase.instance;
  List<ProviderAccountMapping> mappings = const [];
  List<Account> accounts = const [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      database.providerAccountMappings(),
      database.accounts(),
    ]);
    if (mounted) {
      setState(() {
        mappings = (values[0] as List<ProviderAccountMapping>)
            .where((m) => m.providerId == widget.provider.id)
            .toList();
        accounts = values[1] as List<Account>;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapped = mappings.map((m) => m.accountId).toSet();
    return Scaffold(
      appBar: AppBar(title: Text(widget.provider.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const FlowlySurface(
            child: Text(
              'Map this recognized provider to Flowly accounts. This does not assume any SIM-to-account relationship.',
            ),
          ),
          const SizedBox(height: 14),
          ...mappings.map((mapping) {
            final account = accounts
                .where((a) => a.id == mapping.accountId)
                .firstOrNull;
            return ListTile(
              title: Text(account?.name ?? 'Archived account'),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () async {
                  await database.removeProviderAccountMapping(mapping.id!);
                  await _load();
                },
              ),
            );
          }),
          if (accounts.any((a) => !mapped.contains(a.id)))
            ListTile(
              leading: const Icon(Icons.add_link),
              title: const Text('Map an account'),
              onTap: () async {
                final account = await showModalBottomSheet<Account>(
                  context: context,
                  builder: (context) => ListView(
                    children: accounts
                        .where((a) => !mapped.contains(a.id))
                        .map(
                          (a) => ListTile(
                            title: Text(a.name),
                            onTap: () => Navigator.pop(context, a),
                          ),
                        )
                        .toList(),
                  ),
                );
                if (account != null) {
                  await database.setProviderAccountMapping(
                    widget.provider.id!,
                    account.id!,
                  );
                  await _load();
                }
              },
            ),
        ],
      ),
    );
  }
}

class _ProviderIntro extends StatelessWidget {
  const _ProviderIntro();
  @override
  Widget build(BuildContext context) => FlowlySurface(
    child: Row(children: [
      const FlowlyIcon(icon: Icons.privacy_tip_outlined),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recognized providers', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 3),
        const Text('Use the sender name shown on your device. Messages are processed on this device.'),
      ])),
    ]),
  );
}
