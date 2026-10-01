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
            icon: Icons.delete_outline,
            label: 'Delete goal',
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
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  Center(
                    child: _ProgressRing(
                      value: current.progress,
                      percent: '${(current.progress * 100).round()}%',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DetailsTable(
                    rows: [
                      (
                        'Target amount',
                        MoneyFormatter.format(current.targetMinor),
                      ),
                      (
                        'Current amount',
                        MoneyFormatter.format(current.currentMinor),
                      ),
                      ('Remaining', MoneyFormatter.format(remaining)),
                      ('Target date', _date(current.targetDate)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Contribution history',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<Map<String, Object?>>>(
                    future: AppDatabase.instance.goalContributions(current.id!),
                    builder: (context, snapshot) {
                      final entries = snapshot.data ?? const [];
                      if (entries.isEmpty) return const _EmptyContributions();
                      return Container(
                        decoration: _surfaceBox(context),
                        child: Column(
                          children: entries.indexed.map((entry) {
                            final (index, item) = entry;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: index == 0
                                    ? null
                                    : Border(
                                        top: BorderSide(
                                          color: AppColors.lightBorder
                                              .withValues(alpha: .7),
                                        ),
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.incomeSoft,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: AppColors.income,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Contribution',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          _shortDate(
                                            item['contributed_at'] as String,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    MoneyFormatter.signed(
                                      item['amount'] as int,
                                      negative: false,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.income,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Contribution'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContributionScreen(goal: current),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, required this.percent});
  final double value;
  final String percent;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 136,
    height: 136,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 122,
          height: 122,
          child: CircularProgressIndicator(
            value: value.clamp(0, 1),
            color: AppColors.primary,
            backgroundColor: AppColors.primary.withValues(alpha: .07),
            strokeWidth: 11,
            strokeCap: StrokeCap.round,
          ),
        ),
        Text(
          percent,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.rows});
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: _surfaceBox(context),
    child: Column(
      children: rows.indexed.map((entry) {
        final (index, row) = entry;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: index == 0
                ? null
                : Border(
                    top: BorderSide(
                      color: AppColors.lightBorder.withValues(alpha: .7),
                    ),
                  ),
          ),
          child: Row(
            children: [
              Text(row.$1, style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              Text(
                row.$2,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class _GoalAction extends StatelessWidget {
  const _GoalAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    style: IconButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: AppColors.lightBorder),
    ),
  );
}

class _EmptyContributions extends StatelessWidget {
  const _EmptyContributions();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _surfaceBox(context),
    child: Text(
      'No contributions yet.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

BoxDecoration _surfaceBox(BuildContext context) => BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: BorderRadius.circular(10),
  border: Border.all(color: AppColors.lightBorder),
);
String _date(DateTime? value) => value == null
    ? 'Not set'
    : '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value.month - 1]} ${value.day}, ${value.year}';
String _shortDate(String value) {
  final date = DateTime.tryParse(value);
  return date == null
      ? value.split('T').first
      : '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.day}';
}
