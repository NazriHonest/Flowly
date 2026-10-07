import 'package:flowly/core/formatters/money_formatter.dart';
import 'package:flowly/core/theme/app_colors.dart';
import 'package:flowly/core/widgets/app_widgets.dart';
import 'package:flowly/features/goals/domain/entities/goal.dart';
import 'package:flowly/features/goals/presentation/goal_details_screen.dart';
import 'package:flowly/features/goals/presentation/goal_form_screen.dart';
import 'package:flowly/features/goals/providers/goal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              tooltip: 'Add goal',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
              onPressed: () => _openAddGoal(context),
            ),
          ),
        ],
      ),
      body: state.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(
          title: 'Couldn’t load goals',
          message: 'Please try again.',
          onRetry: () => ref.invalidate(goalListProvider),
        ),
        data: (goals) {
          return RefreshIndicator(
            onRefresh: () => ref.read(goalListProvider.notifier).refresh(),
            child: goals.isEmpty
                ? _GoalsEmptyState(onAdd: () => _openAddGoal(context))
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _GoalsOverview(goals: goals),

                      const SizedBox(height: 26),

                      _GoalsSectionHeader(
                        title: 'Your goals',
                        subtitle:
                            '${goals.length} active ${goals.length == 1 ? 'goal' : 'goals'}',
                      ),

                      const SizedBox(height: 12),

                      ...goals.map(
                        (goal) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GoalCard(
                            goal: goal,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GoalDetailsScreen(goal: goal),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _openAddGoal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GoalFormScreen()),
    );
  }
}

class _GoalsOverview extends StatelessWidget {
  const _GoalsOverview({required this.goals});

  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalTarget = goals.fold<int>(
      0,
      (sum, goal) => sum + goal.targetMinor,
    );

    final totalSaved = goals.fold<int>(
      0,
      (sum, goal) => sum + goal.currentMinor,
    );

    final remaining = (totalTarget - totalSaved).clamp(0, totalTarget);

    final progress = totalTarget <= 0 ? 0.0 : totalSaved / totalTarget;

    final completedCount = goals
        .where(
          (goal) =>
              goal.targetMinor > 0 && goal.currentMinor >= goal.targetMinor,
        )
        .length;

    final activeCount = goals.length - completedCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: const Icon(
                  Icons.flag_outlined,
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
                      'Savings goals',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your progress across all goals',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.heroTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'TOTAL SAVED',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.heroTextMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            MoneyFormatter.format(totalSaved),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'of ${MoneyFormatter.format(totalTarget)} total target',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.heroTextMuted,
            ),
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Text(
                '${(progress * 100).round()}% saved',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${MoneyFormatter.format(remaining)} remaining',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _GoalOverviewMetric(
                    icon: Icons.flag_outlined,
                    value: '${goals.length}',
                    label: 'Total goals',
                  ),
                ),
                const _GoalOverviewDivider(),
                Expanded(
                  child: _GoalOverviewMetric(
                    icon: Icons.trending_up_rounded,
                    value: '$activeCount',
                    label: 'In progress',
                  ),
                ),
                const _GoalOverviewDivider(),
                Expanded(
                  child: _GoalOverviewMetric(
                    icon: Icons.check_circle_outline_rounded,
                    value: '$completedCount',
                    label: 'Completed',
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final progress = goal.progress;

    final remaining = (goal.targetMinor - goal.currentMinor).clamp(
      0,
      goal.targetMinor,
    );

    final completed =
        goal.targetMinor > 0 && goal.currentMinor >= goal.targetMinor;

    final progressColor = completed ? AppColors.income : AppColors.primary;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: completed
                  ? AppColors.income.withValues(alpha: 0.20)
                  : colors.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      completed
                          ? Icons.check_circle_outline_rounded
                          : Icons.flag_outlined,
                      color: progressColor,
                      size: 23,
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          goal.targetDate == null
                              ? 'No target date'
                              : 'Target ${_goalDate(context, goal.targetDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  _GoalStatusPill(completed: completed, progress: progress),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _GoalAmount(
                      label: 'SAVED',
                      amount: goal.currentMinor,
                      color: progressColor,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _GoalAmount(
                      label: 'TARGET',
                      amount: goal.targetMinor,
                      alignment: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: progressColor.withValues(alpha: 0.10),
                  color: progressColor,
                ),
              ),

              const SizedBox(height: 9),

              Row(
                children: [
                  Text(
                    completed
                        ? 'Goal reached'
                        : '${(progress * 100).round()}% complete',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    completed
                        ? 'Completed'
                        : '${MoneyFormatter.format(remaining)} remaining',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: completed
                          ? AppColors.income
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalAmount extends StatelessWidget {
  const _GoalAmount({
    required this.label,
    required this.amount,
    this.color,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final int amount;
  final Color? color;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          MoneyFormatter.format(amount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _GoalStatusPill extends StatelessWidget {
  const _GoalStatusPill({required this.completed, required this.progress});

  final bool completed;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppColors.income : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_rounded : Icons.trending_up_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            completed ? 'Completed' : '${(progress * 100).round()}%',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _GoalOverviewMetric extends StatelessWidget {
  const _GoalOverviewMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 5),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.heroTextMuted,
          ),
        ),
      ],
    );
  }
}

class _GoalOverviewDivider extends StatelessWidget {
  const _GoalOverviewDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: 0.15),
    );
  }
}

class _GoalsSectionHeader extends StatelessWidget {
  const _GoalsSectionHeader({required this.title, required this.subtitle});

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
          ),
        ),
      ],
    );
  }
}

class _GoalsEmptyState extends StatelessWidget {
  const _GoalsEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: AppEmptyState(
            icon: Icons.flag_outlined,
            title: 'Start a savings goal',
            message: 'Set a target for something that matters and track your progress as your savings grow.',
            actionLabel: 'Create goal',
            onAction: onAdd,
          ),
        ),
      ],
    );
  }
}

String _goalDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMediumDate(date);
}
