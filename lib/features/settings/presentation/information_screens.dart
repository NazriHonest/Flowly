import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Help & support')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: const [
        FlowlySurface(child: Row(children: [FlowlyIcon(icon: Icons.support_agent_rounded, size: 52), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('How can we help?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Quick answers for keeping your finances on track.')]))])),
        SizedBox(height: 16),
        FlowlySurface(child: ExpansionTile(
          title: Text('Adding transactions and transfers'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Use Transactions to add income, expenses, or transfers. A transfer moves money between two different accounts and is not counted as income or spending.',
              ),
            ),
          ],
        )),
        SizedBox(height: 8),
        FlowlySurface(child: ExpansionTile(
          title: Text('Accounts, categories and budgets'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Accounts hold balances. Categories organize income and expenses. Budgets track confirmed spending in one category; transfers do not affect them.',
              ),
            ),
          ],
        )),
        SizedBox(height: 8),
        FlowlySurface(child: ExpansionTile(
          title: Text('Goals and recurring transactions'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Set a goal and record contributions to follow progress. Recurring transactions generate a confirmed entry when their next occurrence is due.',
              ),
            ),
          ],
        )),
        SizedBox(height: 8),
        FlowlySurface(child: ExpansionTile(
          title: Text('Automatic detection'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Detection is optional and processes incoming messages only in memory.',
              ),
            ),
          ],
        )),
        SizedBox(height: 8),
        FlowlySurface(child: ExpansionTile(
          title: Text('SMS permissions'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('You can use Flowly manually without SMS access.'),
            ),
          ],
        )),
        SizedBox(height: 8),
        FlowlySurface(child: ExpansionTile(
          title: Text('Duplicates and review'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Flowly fingerprints detected transactions and sends uncertain items to Needs Review.',
              ),
            ),
          ],
        )),
        SizedBox(height: 8),
        FlowlySurface(child: ExpansionTile(
          title: Text('Backup, export and security'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'These tools only include stored financial data, never raw SMS bodies.',
              ),
            ),
          ],
        )),
      ],
    ),
  );
}

class PrivacyInformationScreen extends StatelessWidget {
  const PrivacyInformationScreen({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Privacy')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(child: Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(c).colorScheme.primary.withValues(alpha: .12)), child: Icon(Icons.verified_user_outlined, color: Theme.of(c).colorScheme.primary, size: 34))),
        const SizedBox(height: 16),
        Text('Your data stays yours', textAlign: TextAlign.center, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        const _PrivacyRow(Icons.phone_android_outlined, 'On-device processing', 'SMS is analyzed only on your phone.'),
        const _PrivacyRow(Icons.sms_outlined, 'Raw SMS is transient', 'Messages are discarded after detection.'),
        const _PrivacyRow(Icons.storage_outlined, 'Local-first storage', 'Financial data lives on this device.'),
        const _PrivacyRow(Icons.file_download_outlined, 'No raw SMS in exports', 'Exports contain only transaction data.'),
        const _PrivacyRow(Icons.backup_outlined, 'No raw SMS in backups', 'Backups exclude message text.'),
        const _PrivacyRow(Icons.check_circle_outline, 'Optional detection', 'You choose whether to enable it.'),
      ],
    ),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('About')),
    body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: Theme.of(c).colorScheme.primary, borderRadius: BorderRadius.circular(18)), child: Icon(Icons.show_chart_rounded, color: Theme.of(c).colorScheme.onPrimary, size: 34)),
      const SizedBox(height: 16), Text('Flowly', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('Version 1.0.0', style: Theme.of(c).textTheme.labelMedium), const SizedBox(height: 10), Text('Your Money. Your Control.', style: TextStyle(color: Theme.of(c).colorScheme.primary, fontWeight: FontWeight.w700)), const SizedBox(height: 20), const Text('Flowly is a privacy-first personal finance app designed to help you understand and manage your money while keeping sensitive financial processing on your device.', textAlign: TextAlign.center),
    ])),
  )
  );
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow(this.icon, this.title, this.subtitle);
  final IconData icon; final String title, subtitle;
  @override Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 18, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .1), child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle));
}
