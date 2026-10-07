import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/entities/goal.dart';
import '../providers/goal_provider.dart';
import 'contribution_screen.dart';
import 'goal_form_screen.dart';

class GoalDetailsScreen extends ConsumerWidget {
  const GoalDetailsScreen({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref
            .watch(goalListProvider)
            .valueOrNull
            ?.where((item) => item.id == goal.id)
            .firstOrNull ??
        goal;

    final remaining = (current.targetMinor - current.currentMinor).clamp(
      0,
      current.targetMinor,
    );

    final completed =
        current.targetMinor > 0 && current.currentMinor >= current.targetMinor;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          _GoalAction(
            icon: Icons.edit_outlined,
            label: 'Edit goal',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GoalFormScreen(goal: current)),
            ),
          ),
          const SizedBox(width: 6),
          _GoalAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete goal',
            destructive: true,
            onTap: () async {
              if (!await showFlowlyConfirmation(
                context,
                title: 'Delete goal?',
                message: 'This permanently removes the goal and its contribution history.',
                confirmLabel: 'Delete goal',
              )) {
                return;
              }

              await ref.read(goalListProvider.notifier).delete(current.id!);

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _GoalProgressHero(
                    goal: current,
                    remainingMinor: remaining,
                    completed: completed,
                  ),

                  const SizedBox(height: 26),

                  const _SectionHeader(
                    title: 'Goal details',
                    subtitle:
                        'Your target, progress and planned completion date.',
                  ),

                  const SizedBox(height: 12),

                  _DetailsCard(
                    goal: current,
                    remainingMinor: remaining,
                    completed: completed,
                  ),

                  const SizedBox(height: 26),

                  _ContributionHistory(goal: current),
                ],
              ),
            ),

            _ContributionActionBar(
              completed: completed,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContributionScreen(goal: current),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalProgressHero extends StatelessWidget {
  const _GoalProgressHero({
    required this.goal,
    required this.remainingMinor,
    required this.completed,
  });

  final Goal goal;
  final int remainingMinor;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final progress = goal.progress;
    final displayProgress = progress.clamp(0.0, 1.0);

    final accent = completed ? AppColors.income : AppColors.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: completed
              ? [AppColors.income, AppColors.primary]
              : [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  completed ? Icons.check_rounded : Icons.flag_outlined,
                  color: Colors.white,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      completed ? 'Goal reached' : 'Savings progress',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      completed
                          ? 'You reached your savings target.'
                          : 'Keep building toward your target.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.heroTextMuted,
                      ),
                    ),
                  ],
                ),
              ),

              _HeroStatusBadge(
                completed: completed,
                percentage: (progress * 100).round(),
              ),
            ],
          ),

          const SizedBox(height: 26),

          _HeroProgressRing(
            value: displayProgress,
            percent: '${(progress * 100).round()}%',
            completed: completed,
          ),

          const SizedBox(height: 22),

          Text(
            MoneyFormatter.format(goal.currentMinor),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'saved of ${MoneyFormatter.format(goal.targetMinor)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.heroTextMuted,
            ),
          ),

          const SizedBox(height: 20),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: displayProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 11),

          Row(
            children: [
              Text(
                completed
                    ? 'Target completed'
                    : '${(progress * 100).round()}% complete',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const Spacer(),

              Text(
                completed
                    ? 'Goal reached'
                    : '${MoneyFormatter.format(remainingMinor)} remaining',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.white,
                  size: 18,
                ),

                const SizedBox(width: 9),

                Text(
                  'Target date',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.heroTextMuted,
                  ),
                ),

                const Spacer(),

                Text(
                  _date(goal.targetDate),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

class _HeroProgressRing extends StatelessWidget {
  const _HeroProgressRing({
    required this.value,
    required this.percent,
    required this.completed,
  });

  final double value;
  final String percent;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 116,
            height: 116,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.17),
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                completed ? Icons.check_rounded : Icons.savings_outlined,
                color: Colors.white,
                size: 21,
              ),

              const SizedBox(height: 3),

              Text(
                percent,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),

              Text(
                completed ? 'DONE' : 'SAVED',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.heroTextMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatusBadge extends StatelessWidget {
  const _HeroStatusBadge({required this.completed, required this.percentage});

  final bool completed;
  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed
                ? Icons.check_circle_outline_rounded
                : Icons.trending_up_rounded,
            color: Colors.white,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            completed ? 'Completed' : '$percentage%',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.goal,
    required this.remainingMinor,
    required this.completed,
  });

  final Goal goal;
  final int remainingMinor;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _surfaceBox(context),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.track_changes_outlined,
            label: 'Target amount',
            value: MoneyFormatter.format(goal.targetMinor),
          ),

          _DetailDivider(),

          _DetailRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Saved amount',
            value: MoneyFormatter.format(goal.currentMinor),
            valueColor: AppColors.primary,
          ),

          _DetailDivider(),

          _DetailRow(
            icon: completed
                ? Icons.check_circle_outline_rounded
                : Icons.savings_outlined,
            label: completed ? 'Status' : 'Remaining',
            value: completed
                ? 'Completed'
                : MoneyFormatter.format(remainingMinor),
            valueColor: completed ? AppColors.income : null,
          ),

          _DetailDivider(),

          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Target date',
            value: _date(goal.targetDate),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: valueColor ?? AppColors.primary, size: 19),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 65,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _ContributionHistory extends StatelessWidget {
  const _ContributionHistory({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: AppDatabase.instance.goalContributions(goal.id!),
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Contribution history',
                subtitle: 'Money added toward this goal.',
              ),

              const SizedBox(height: 12),

              Container(
                height: 90,
                width: double.infinity,
                decoration: _surfaceBox(context),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Contribution history',
                subtitle: 'Money added toward this goal.',
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: _surfaceBox(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.expense,
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Couldn’t load contributions',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Open the screen again to retry.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final entries = snapshot.data ?? const [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Contribution history',
              subtitle: entries.isEmpty
                  ? 'No contributions recorded yet'
                  : '${entries.length} ${entries.length == 1 ? 'contribution' : 'contributions'} recorded',
            ),

            const SizedBox(height: 12),

            if (entries.isEmpty)
              const _EmptyContributions()
            else
              Container(
                decoration: _surfaceBox(context),
                child: Column(
                  children: entries.indexed.map((entry) {
                    final (index, item) = entry;

                    return Column(
                      children: [
                        if (index > 0)
                          Divider(
                            height: 1,
                            indent: 68,
                            color: colors.outlineVariant,
                          ),

                        _ContributionRow(item: item),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({required this.item});

  final Map<String, Object?> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final amount = item['amount'] as int;
    final contributedAt = item['contributed_at'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.income,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contribution',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _shortDate(contributedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            MoneyFormatter.signed(amount, negative: false),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.income,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContributions extends StatelessWidget {
  const _EmptyContributions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: _surfaceBox(context),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_outlined,
              color: AppColors.primary,
              size: 25,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'No contributions yet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Add your first contribution to start building progress toward this goal.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionActionBar extends StatelessWidget {
  const _ContributionActionBar({
    required this.completed,
    required this.onPressed,
  });

  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(
            completed ? Icons.add_circle_outline_rounded : Icons.add_rounded,
          ),
          label: Text(
            completed ? 'Add another contribution' : 'Add contribution',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _GoalAction extends StatelessWidget {
  const _GoalAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final foreground = destructive ? AppColors.expense : colors.onSurface;

    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 42),
        backgroundColor: destructive
            ? AppColors.expense.withValues(alpha: 0.07)
            : colors.surface,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        side: BorderSide(
          color: destructive
              ? AppColors.expense.withValues(alpha: 0.16)
              : colors.outlineVariant,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

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
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

BoxDecoration _surfaceBox(BuildContext context) {
  final colors = Theme.of(context).colorScheme;

  return BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: colors.outlineVariant),
  );
}

String _date(DateTime? value) {
  if (value == null) {
    return 'Not set';
  }

  return '${_month(value.month)} ${value.day}, ${value.year}';
}

String _shortDate(String value) {
  final date = DateTime.tryParse(value);

  if (date == null) {
    return value.split('T').first;
  }

  return '${_month(date.month)} ${date.day}, ${date.year}';
}

String _month(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
