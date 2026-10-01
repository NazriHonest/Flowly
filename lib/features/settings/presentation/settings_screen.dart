import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_provider.dart';
import '../../sms_detection/presentation/sms_permission_education_screen.dart';
import 'data_tools_screen.dart';
import '../../security/presentation/security_screen.dart';
import '../../notifications/presentation/notification_preferences_screen.dart';
import '../../sms_detection/presentation/historical_import_screen.dart';
import '../../sms_detection/presentation/provider_management_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef r) {
    final mode = r.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          FlowlySection(
            title: 'General',
            children: [
              _SettingsTile(
                icon: Icons.currency_exchange_outlined,
                title: 'Currency',
                subtitle: MoneyFormatter.currencyCode,
                onTap: () => _chooseCurrency(c),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: _themeModeLabel(mode),
                onTap: () => _showAppearance(c, r, mode),
              ),
            ],
          ),
          FlowlySection(
            title: 'Automatic detection',
            children: [
              _SettingsTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Automatic detection',
                subtitle: 'Optional on-device SMS processing',
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) => const SmsPermissionEducationScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.account_tree_outlined,
                title: 'SMS providers',
                subtitle: 'Providers and account mappings',
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) => const ProviderManagementScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.download_for_offline_outlined,
                title: 'Historical import',
                subtitle: 'Review supported past messages',
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) => const HistoricalImportScreen(),
                  ),
                ),
              ),
            ],
          ),
          FlowlySection(
            title: 'Preferences',
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notification preferences',
                subtitle: 'Choose which financial events notify you',
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Security',
                subtitle: 'PIN, biometrics and lock timeout',
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const SecurityScreen()),
                ),
              ),
            ],
          ),
          FlowlySection(
            title: 'Data',
            children: [
              _SettingsTile(
                icon: Icons.ios_share_outlined,
                title: 'Export',
                subtitle: 'CSV, Excel workbook or PDF report',
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const DataToolsScreen()),
                ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.backup_outlined,
                title: 'Backup & restore',
                subtitle: 'Create or restore a local backup',
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const DataToolsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chooseCurrency(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['KES', 'USD', 'EUR', 'GBP']
              .map(
                (code) => ListTile(
                  title: Text(code),
                  trailing: code == MoneyFormatter.currencyCode
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(sheet, code),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (choice == null) return;
    await (await SharedPreferences.getInstance()).setString(
      'defaultCurrency',
      choice,
    );
    MoneyFormatter.configure(choice);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Currency changed to $choice.')));
    }
  }

  void _showAppearance(
    BuildContext context,
    WidgetRef ref,
    ThemeMode selected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Choose how Flowly looks on this device.'),
            const SizedBox(height: 18),
            Row(
              children: ThemeMode.values
                  .map(
                    (mode) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _AppearanceChoice(
                          mode: mode,
                          selected: selected == mode,
                          onTap: () {
                            ref.read(themeModeProvider.notifier).set(mode);
                            Navigator.pop(sheet);
                          },
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

String _themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System default',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    leading: FlowlyIcon(icon: icon, size: 40),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: Icon(
      Icons.chevron_right_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    onTap: onTap,
  );
}

class _AppearanceChoice extends StatelessWidget {
  const _AppearanceChoice({
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 94,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: .5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            mode == ThemeMode.dark
                ? Icons.dark_mode_outlined
                : mode == ThemeMode.light
                ? Icons.light_mode_outlined
                : Icons.brightness_auto_outlined,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 7),
          Text(
            mode.name[0].toUpperCase() + mode.name.substring(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
