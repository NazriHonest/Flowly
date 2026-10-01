import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/formatters/money_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../categories/providers/category_provider.dart';
import '../../domain/entities/transaction.dart';

/// The single visual language for transaction rows across the app.
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
    final category = (ref.watch(categoryListProvider).valueOrNull ?? [])
        .where((item) => item.name == transaction.category)
        .firstOrNull;
    final transfer = transaction.type == TransactionType.transfer;
    final income = transaction.type == TransactionType.income;
    final typeColor = income
        ? AppColors.income
        : transfer
        ? AppColors.transfer
        : AppColors.expense;
    final visualColor = transfer
        ? typeColor
        : category == null
        ? typeColor
        : Color(category.color);
    final visualIcon = transfer
        ? Icons.swap_horiz_rounded
        : category == null
        ? (income ? Icons.south_west_rounded : Icons.north_east_rounded)
        : IconData(category.icon, fontFamily: 'MaterialIcons');
    final amount = MoneyFormatter.signed(
      transaction.amountMinor,
      negative: !income && !transfer,
      plus: income,
    );
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: visualColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(visualIcon, color: visualColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      showSource
                          ? '${transaction.category} • ${transaction.source.name}'
                          : transaction.category,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('HH:mm').format(transaction.date),
                    style: Theme.of(context).textTheme.bodySmall,
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
