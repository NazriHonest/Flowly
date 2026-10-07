import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters/money_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../categories/providers/category_provider.dart';
import '../../domain/entities/transaction.dart';
import '../transaction_presentation.dart';

/// The single visual language for transaction rows across the app.
///
/// Transaction semantics:
/// - Income   → green amount
/// - Expense  → red amount
/// - Transfer → blue amount
///
/// Source semantics:
/// - Auto      → emerald
/// - Manual    → purple
/// - Imported  → blue
/// - Recurring → amber
class TransactionCard extends ConsumerWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.showSource = true,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final bool showSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semanticColors = FlowlySemanticColors.of(context);

    final category = (ref.watch(categoryListProvider).valueOrNull ?? [])
        .where((item) => item.name == transaction.category)
        .firstOrNull;

    final transfer = transaction.type == TransactionType.transfer;
    final income = transaction.type == TransactionType.income;

    final typeBaseColor = income
        ? AppColors.income
        : transfer
        ? AppColors.transfer
        : AppColors.expense;
    final typeColor = income
        ? semanticColors.incomeForeground
        : transfer
        ? semanticColors.transferForeground
        : semanticColors.expenseForeground;

    final visualColor = transfer
        ? typeBaseColor
        : category == null
        ? typeBaseColor
        : Color(category.color);

    final visualIcon = transfer
        ? Icons.swap_horiz_rounded
        : category == null
        ? income
              ? Icons.south_west_rounded
              : Icons.north_east_rounded
        : IconData(category.icon, fontFamily: 'MaterialIcons');

    final amount = MoneyFormatter.signed(
      transaction.amountMinor,
      negative: !income && !transfer,
      plus: income,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TransactionIcon(icon: visualIcon, color: visualColor),

                const SizedBox(width: 12),

                Expanded(
                  child: _TransactionIdentity(
                    title: transaction.title,
                    category: transaction.category,
                    source: transaction.source,
                    showSource: showSource,
                  ),
                ),

                const SizedBox(width: 10),

                _TransactionValue(
                  amount: amount,
                  amountColor: typeColor,
                  date: formatTransactionDate(context, transaction.date),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionIcon extends StatelessWidget {
  const _TransactionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _TransactionIdentity extends StatelessWidget {
  const _TransactionIdentity({
    required this.title,
    required this.category,
    required this.source,
    required this.showSource,
  });

  final String title;
  final String category;
  final TransactionSource source;
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 5),

        Row(
          children: [
            Flexible(
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            if (showSource) ...[
              const SizedBox(width: 7),
              _SourceBadge(source: source),
            ],
          ],
        ),
      ],
    );
  }
}

class _TransactionValue extends StatelessWidget {
  const _TransactionValue({
    required this.amount,
    required this.amountColor,
    required this.date,
  });

  final String amount;
  final Color amountColor;
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          amount,
          maxLines: 1,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          date,
          maxLines: 1,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final TransactionSource source;

  @override
  Widget build(BuildContext context) {
    final style = _sourceStyle(context, source);
    final theme = Theme.of(context);

    return Semantics(
      label: 'Transaction source: ${source.displayLabel}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: style.foregroundColor.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 12, color: style.foregroundColor),
            const SizedBox(width: 4),
            Text(
              source.displayLabel,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: style.foregroundColor,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_SourceStyle _sourceStyle(BuildContext context, TransactionSource source) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  switch (source) {
    case TransactionSource.smsLive:
      return _SourceStyle(
        icon: Icons.bolt_rounded,
        foregroundColor: isDark
            ? const Color(0xFF6EE7B7)
            : const Color(0xFF047857),
        backgroundColor: isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.42)
            : const Color(0xFFD1FAE5),
      );

    case TransactionSource.manual:
      return _SourceStyle(
        icon: Icons.touch_app_outlined,
        foregroundColor: isDark
            ? const Color(0xFFC4B5FD)
            : const Color(0xFF6D28D9),
        backgroundColor: isDark
            ? const Color(0xFF4C1D95).withValues(alpha: 0.38)
            : const Color(0xFFEDE9FE),
      );

    case TransactionSource.smsImport:
      return _SourceStyle(
        icon: Icons.download_rounded,
        foregroundColor: isDark
            ? const Color(0xFF7DD3FC)
            : const Color(0xFF0369A1),
        backgroundColor: isDark
            ? const Color(0xFF0C4A6E).withValues(alpha: 0.42)
            : const Color(0xFFE0F2FE),
      );

    case TransactionSource.recurring:
      return _SourceStyle(
        icon: Icons.repeat_rounded,
        foregroundColor: isDark
            ? const Color(0xFFFCD34D)
            : const Color(0xFFB45309),
        backgroundColor: isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.38)
            : const Color(0xFFFEF3C7),
      );
  }
}

class _SourceStyle {
  const _SourceStyle({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
}
