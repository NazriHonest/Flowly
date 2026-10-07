import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';


class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _HelpHero(),

          const SizedBox(height: 28),

          _SectionTitle(
            title: 'Using Flowly',
            subtitle: 'Learn how the main finance features work.',
          ),

          const SizedBox(height: 12),

          const _HelpTopic(
            icon: Icons.receipt_long_outlined,
            title: 'Transactions & transfers',
            description:
                'Adding income, expenses and moving money between accounts.',
            children: [
              _HelpAnswerSection(
                title: 'Adding transactions',
                text:
                    'Use Transactions to record income, expenses, or transfers. '
                    'Manual transactions are useful when a payment was not '
                    'automatically detected.',
              ),
              _HelpAnswerSection(
                title: 'Transfers',
                text:
                    'A transfer moves money between two different accounts you '
                    'own. Transfers are not counted as income or spending, so '
                    'moving your own money does not distort your financial totals.',
              ),
            ],
          ),

          const SizedBox(height: 10),

          const _HelpTopic(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Accounts, categories & budgets',
            description: 'Organize balances, spending categories and limits.',
            children: [
              _HelpAnswerSection(
                title: 'Accounts',
                text:
                    'Accounts represent the places where you keep money and are '
                    'used to calculate your current balances.',
              ),
              _HelpAnswerSection(
                title: 'Categories',
                text:
                    'Categories organize income and expenses so you can understand '
                    'where money comes from and where it goes.',
              ),
              _HelpAnswerSection(
                title: 'Budgets',
                text:
                    'Budgets help you track confirmed spending for a category. '
                    'Internal transfers do not count as budget spending.',
              ),
            ],
          ),

          const SizedBox(height: 10),

          const _HelpTopic(
            icon: Icons.flag_outlined,
            title: 'Goals & recurring transactions',
            description: 'Track savings targets and transactions that repeat.',
            children: [
              _HelpAnswerSection(
                title: 'Goals',
                text:
                    'Create a financial goal and record contributions to track '
                    'your progress toward the target.',
              ),
              _HelpAnswerSection(
                title: 'Recurring transactions',
                text:
                    'Recurring transactions help Flowly represent payments or '
                    'income that repeat on a schedule. When the next occurrence '
                    'is due, a confirmed transaction entry is generated.',
              ),
            ],
          ),

          const SizedBox(height: 28),

          _SectionTitle(
            title: 'Automatic detection',
            subtitle:
                'Understand SMS detection, permissions and transaction review.',
          ),

          const SizedBox(height: 12),

          const _HelpTopic(
            icon: Icons.auto_awesome_outlined,
            title: 'How automatic detection works',
            description:
                'Flowly can detect supported financial transactions on-device.',
            children: [
              _HelpAnswerSection(
                title: 'Optional feature',
                text:
                    'Automatic detection is optional. You can continue using '
                    'Flowly manually without enabling SMS access.',
              ),
              _HelpAnswerSection(
                title: 'On-device processing',
                text:
                    'Supported financial messages are processed on your device '
                    'to identify transaction information. Flowly stores the '
                    'normalized financial transaction, not the raw SMS body.',
              ),
            ],
          ),

          const SizedBox(height: 10),

          const _HelpTopic(
            icon: Icons.sms_outlined,
            title: 'SMS permissions',
            description: 'Why Flowly may request access to financial messages.',
            children: [
              _HelpAnswerSection(
                title: 'Why permission is requested',
                text:
                    'SMS access is used only when you choose to enable automatic '
                    'financial transaction detection.',
              ),
              _HelpAnswerSection(
                title: 'Using Flowly without SMS',
                text:
                    'SMS permission is not required for manual finance tracking. '
                    'You can add and manage transactions yourself.',
              ),
            ],
          ),

          const SizedBox(height: 10),

          const _HelpTopic(
            icon: Icons.fact_check_outlined,
            title: 'Duplicates & Needs Review',
            description:
                'How Flowly handles repeated and uncertain detections.',
            children: [
              _HelpAnswerSection(
                title: 'Duplicate protection',
                text:
                    'Flowly fingerprints detected transactions to help prevent '
                    'the same financial event from being imported more than once.',
              ),
              _HelpAnswerSection(
                title: 'Needs Review',
                text:
                    'When Flowly is not confident enough about a detected '
                    'transaction, it can place the item in Needs Review instead '
                    'of silently treating uncertain information as confirmed.',
              ),
            ],
          ),

          const SizedBox(height: 28),

          _SectionTitle(
            title: 'Your data',
            subtitle: 'Export, backup and security information.',
          ),

          const SizedBox(height: 12),

          const _HelpTopic(
            icon: Icons.folder_copy_outlined,
            title: 'Export, backup & restore',
            description:
                'Keep copies of your financial records or move them safely.',
            children: [
              _HelpAnswerSection(
                title: 'Export',
                text:
                    'Data tools can export normalized financial information for '
                    'reporting and personal use.',
              ),
              _HelpAnswerSection(
                title: 'Backup & restore',
                text:
                    'You can create a local backup and restore a supported Flowly '
                    'backup when needed.',
              ),
              _HelpAnswerSection(
                title: 'Raw messages',
                text: 'Raw SMS bodies are not included in Flowly exports or backups.',
              ),
            ],
          ),

          const SizedBox(height: 10),

          const _HelpTopic(
            icon: Icons.lock_outline_rounded,
            title: 'PIN & biometric security',
            description: 'Protect access to your financial information.',
            children: [
              _HelpAnswerSection(
                title: 'App lock',
                text:
                    'Flowly can protect access with your PIN. When supported and '
                    'enabled, biometric authentication can also be used to unlock '
                    'the app.',
              ),
            ],
          ),

          const SizedBox(height: 24),

          const _SupportNote(),
        ],
      ),
    );
  }
}

class PrivacyInformationScreen extends StatelessWidget {
  const PrivacyInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Your data stays yours',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  'Flowly is designed around local, privacy-conscious '
                  'financial tracking.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          _SectionTitle(
            title: 'How Flowly protects your data',
            subtitle: 'The core privacy principles used throughout the app.',
          ),

          const SizedBox(height: 12),

          const _PrivacyCard(
            children: [
              _PrivacyRow(
                Icons.phone_android_outlined,
                'On-device processing',
                'Supported financial SMS is analyzed on your phone.',
              ),
              _PrivacyRow(
                Icons.sms_outlined,
                'Raw SMS is not stored',
                'Flowly stores normalized financial information instead of the raw message body.',
              ),
              _PrivacyRow(
                Icons.storage_outlined,
                'Local-first storage',
                'Your financial records are stored locally on this device.',
              ),
              _PrivacyRow(
                Icons.file_download_outlined,
                'Private exports',
                'Exports contain normalized financial records, never raw SMS bodies.',
              ),
              _PrivacyRow(
                Icons.backup_outlined,
                'Private backups',
                'Flowly backups exclude raw financial message text.',
              ),
              _PrivacyRow(
                Icons.toggle_on_outlined,
                'Detection is optional',
                'You decide whether automatic SMS detection is enabled.',
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can use Flowly as a manual finance tracker '
                    'without granting SMS access.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const SizedBox(height: 16),

          Center(
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: const Icon(
                Icons.show_chart_rounded,
                color: AppColors.onPrimary,
                size: 42,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Flowly',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Version 1.0.0',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Your Money. Your Control.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Flowly',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Flowly is a privacy-first personal finance app '
                  'designed to help you understand and manage your '
                  'money while keeping sensitive financial processing '
                  'on your device.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _AboutFeature(
                  icon: Icons.phone_android_outlined,
                  title: 'Local-first',
                  subtitle: 'Built around your device',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AboutFeature(
                  icon: Icons.shield_outlined,
                  title: 'Privacy-first',
                  subtitle: 'Sensitive data protected',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _AboutFeature(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Smart',
                  subtitle: 'Automatic detection',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AboutFeature(
                  icon: Icons.insights_outlined,
                  title: 'Insightful',
                  subtitle: 'Understand your money',
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          Text(
            'FLOWLY',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpHero extends StatelessWidget {
  const _HelpHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.primary,
              size: 29,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can we help?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Find quick answers about using Flowly and '
                  'managing your financial data.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HelpTopic extends StatelessWidget {
  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          title: Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
          iconColor: AppColors.primary,
          collapsedIconColor: colors.onSurfaceVariant,
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 14),
            ..._withSpacing(children),
          ],
        ),
      ),
    );
  }

  static List<Widget> _withSpacing(List<Widget> children) {
    final result = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);

      if (i != children.length - 1) {
        result.add(const SizedBox(height: 16));
      }
    }

    return result;
  }
}

class _HelpAnswerSection extends StatelessWidget {
  const _HelpAnswerSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportNote extends StatelessWidget {
  const _SupportNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help understanding a transaction?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open the transaction details to review its '
                  'category, account, source and status.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow(
    this.icon,
    this.title,
    this.subtitle, {
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 52, color: colors.outlineVariant),
      ],
    );
  }
}

class _AboutFeature extends StatelessWidget {
  const _AboutFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 19),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
