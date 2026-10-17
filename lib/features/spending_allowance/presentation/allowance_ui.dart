import 'package:flowly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../../../core/formatters/money_formatter.dart';
import '../domain/entities/spending_allowance.dart';

String allowanceTypeLabel(AllowancePeriodType type) => switch (type) {
  AllowancePeriodType.monthly => 'Monthly',
  AllowancePeriodType.weekly => 'Weekly',
  AllowancePeriodType.daily => 'Daily',
};

String allowanceStatusLabel(AllowanceStatus status) => switch (status) {
  AllowanceStatus.onTrack => 'On Track',
  AllowanceStatus.nearLimit => 'Near Limit',
  AllowanceStatus.limitReached => 'Limit Reached',
  AllowanceStatus.overLimit => 'Over Limit',
};

Color allowanceStatusColor(BuildContext context, AllowanceStatus status) {
  final semantic = FlowlySemanticColors.of(context);
  return switch (status) {
    AllowanceStatus.onTrack => Theme.of(context).colorScheme.primary,
    AllowanceStatus.nearLimit => semantic.warningForeground,
    AllowanceStatus.limitReached || AllowanceStatus.overLimit => semantic.expenseForeground,
  };
}


class AllowanceSummaryBody extends StatelessWidget {
  const AllowanceSummaryBody({
    super.key,
    required this.summary,
    this.compact = false,
  });

  final SpendingAllowanceSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusColor = allowanceStatusColor(context, summary.status);

    final percent = summary.usage * 100;

    final isWarningOrOverLimit = summary.usage >= 0.8;

    final amountColor = isWarningOrOverLimit ? statusColor : colors.onSurface;

    final progress = summary.usage.isFinite
        ? summary.usage.clamp(0.0, 1.0).toDouble()
        : 0.0;

    final percentageText = percent.isFinite
        ? '${percent.toStringAsFixed(percent == percent.roundToDouble() ? 0 : 1)}% used'
        : '0% used';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      MoneyFormatter.format(summary.remainingMinor),
                      style:
                          (compact
                                  ? theme.textTheme.headlineSmall
                                  : theme.textTheme.headlineMedium)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: amountColor,
                              ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              percentageText,
              style: theme.textTheme.labelLarge?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: compact ? 7 : 9,
            color: statusColor,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: Text(
                '${MoneyFormatter.format(summary.spentMinor)} spent',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${MoneyFormatter.format(summary.limitMinor)} limit',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          allowanceStatusLabel(summary.status),
          style: theme.textTheme.labelMedium?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

