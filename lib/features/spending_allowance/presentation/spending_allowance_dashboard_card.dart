import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/spending_allowance.dart';
import '../providers/spending_allowance_provider.dart';
import 'allowance_ui.dart';
import 'spending_allowance_details_screen.dart';
import 'spending_allowance_setup_screen.dart';

class SpendingAllowanceDashboardCard extends ConsumerWidget {
  const SpendingAllowanceDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final config = ref.watch(currentAllowanceProvider);

    Widget cardShell({required Widget child, VoidCallback? onTap}) {
      final radius = BorderRadius.circular(16);
      return Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );
    }

    return config.when(
      loading: () => cardShell(
        child: LinearProgressIndicator(
          color: colors.primary,
          backgroundColor: colors.surfaceContainerHighest,
        ),
      ),
      error: (_, __) => cardShell(
        child: Text(
          'Could not load spending allowance.',
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
        ),
      ),
      data: (configuration) {
        if (configuration == null) {
          return cardShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set your spending allowance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a monthly spending limit and optionally add weekly and daily limits.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SpendingAllowanceSetupScreen(),
                    ),
                  ),
                  child: const Text('Set Allowance'),
                ),
              ],
            ),
          );
        }

        final available = <AllowancePeriodType>[
          AllowancePeriodType.monthly,
          if (configuration.weeklyEnabled) AllowancePeriodType.weekly,
          if (configuration.dailyEnabled) AllowancePeriodType.daily,
        ];
        final storedSelection = ref.watch(
          selectedDashboardAllowancePeriodProvider,
        );
        final selected = available.contains(storedSelection)
            ? storedSelection
            : AllowancePeriodType.monthly;
        final summary = ref.watch(allowanceSummaryProvider(selected));

        return cardShell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SpendingAllowanceDetailsScreen(),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_outlined, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Spending Allowance',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: available.map((period) {
                  final isSelected = selected == period;
                  return ChoiceChip(
                    label: Text(allowanceTypeLabel(period)),
                    selected: isSelected,
                    showCheckmark: false,
                    backgroundColor: colors.surfaceContainerLow,
                    selectedColor: colors.primaryContainer,
                    side: BorderSide(
                      color: isSelected
                          ? colors.primary
                          : colors.outlineVariant,
                    ),
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    onSelected: (_) =>
                        ref
                                .read(
                                  selectedDashboardAllowancePeriodProvider
                                      .notifier,
                                )
                                .state =
                            period,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              summary.when(
                loading: () => LinearProgressIndicator(
                  color: colors.primary,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
                error: (_, __) => Text(
                  'Could not calculate spending.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
                data: (value) => value == null
                    ? Text(
                        'No limit configured.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    : AllowanceSummaryBody(summary: value, compact: true),
              ),
            ],
          ),
        );
      },
    );
  }
}
