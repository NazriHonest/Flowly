import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/presentation/category_visual.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/presentation/transaction_details_screen.dart';
import '../domain/entities/recurring_transaction.dart';
import '../providers/recurring_provider.dart';
import 'recurring_form_screen.dart';

class RecurringDetailsScreen extends ConsumerStatefulWidget {
  const RecurringDetailsScreen({super.key, required this.item});

  final RecurringTransaction item;

  @override
  ConsumerState<RecurringDetailsScreen> createState() =>
      _RecurringDetailsScreenState();
}

class _RecurringDetailsScreenState
    extends ConsumerState<RecurringDetailsScreen> {
  bool _isUpdating = false;
  bool _isArchiving = false;

  RecurringTransaction _resolveCurrent(List<RecurringTransaction>? items) {
    if (items != null) {
      for (final candidate in items) {
        if (candidate.id == widget.item.id) {
          return candidate;
        }
      }
    }

    return widget.item;
  }

  Future<void> _setEnabled(RecurringTransaction item, bool enabled) async {
    if (_isUpdating || _isArchiving) return;

    setState(() => _isUpdating = true);

    try {
      await ref
          .read(recurringListProvider.notifier)
          .setEnabled(item.id!, enabled);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Recurring transaction activated.'
                : 'Recurring transaction paused.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update recurring transaction.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _archive(RecurringTransaction item) async {
    if (_isUpdating || _isArchiving || item.id == null) return;

    final confirmed = await showFlowlyConfirmation(
      context,
      title: 'Archive recurring transaction?',
      message:
          'This recurring transaction will no longer be '
          'generated automatically.',
      confirmLabel: 'Archive',
    );

    if (!confirmed || !mounted) return;

    setState(() => _isArchiving = true);

    try {
      await ref.read(recurringListProvider.notifier).archive(item.id!);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not archive recurring transaction.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isArchiving = false);
      }
    }
  }

  void _edit(RecurringTransaction item) {
    if (_isUpdating || _isArchiving) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecurringFormScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final recurringState = ref.watch(recurringListProvider);
    final item = _resolveCurrent(recurringState.value);

    final categories = ref.watch(recurringCategoriesProvider);
    final categoryVisual = resolveCategoryVisual(
      categories,
      item.category,
      fallbackColor: item.type.name == 'income'
          ? AppColors.income
          : AppColors.expense,
      fallbackIcon: Icons.repeat_rounded,
    );
    final history = item.id == null
        ? const AsyncData<List<Transaction>>([])
        : ref.watch(recurringPaymentHistoryProvider(item.id!));

    final isIncome = item.type.name == 'income';
    final semantic = FlowlySemanticColors.of(context);

    final accent = isIncome
        ? semantic.incomeForeground
        : semantic.expenseForeground;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Recurring Details',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit recurring transaction',
            onPressed: _isUpdating || _isArchiving ? null : () => _edit(item),
            icon: const Icon(Icons.edit_outlined),
          ),
          if (_isArchiving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'More actions',
              enabled: !_isUpdating,
              onSelected: (value) {
                if (value == 'archive') _archive(item);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined),
                      SizedBox(width: 10),
                      Text('Archive'),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          AppLayout.safeScrollBottom(context),
        ),
        children: [
          _RecurringHero(
            item: item,
            accent: accent,
            categoryVisual: categoryVisual,
            isIncome: isIncome,
          ),

          if (item.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: _surfaceDecoration(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 21,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(item.notes, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          _HistoryHeading(
            state: history,
            onViewAll: item.id == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecurringPaymentHistoryScreen(item: item),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          _PaymentHistory(
            state: history,
            categories: categories,
            limit: 3,
            onRetry: item.id == null
                ? null
                : () =>
                      ref.invalidate(recurringPaymentHistoryProvider(item.id!)),
          ),

          const SizedBox(height: 24),

          _SectionTitle(
            title: 'Automatic scheduling',
            subtitle: 'Control whether future transactions are generated.',
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: _surfaceDecoration(context),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.enabled
                        ? Icons.autorenew_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recurring transaction',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.enabled
                            ? 'Active and scheduled'
                            : 'Paused until enabled',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isUpdating)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: item.enabled,
                    onChanged: _isArchiving
                        ? null
                        : (enabled) => _setEnabled(item, enabled),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Hero
// ------------------------------------------------------------

class _RecurringHero extends StatelessWidget {
  const _RecurringHero({
    required this.item,
    required this.accent,
    required this.categoryVisual,
    required this.isIncome,
  });

  final RecurringTransaction item;
  final Color accent;
  final CategoryVisual categoryVisual;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: categoryVisual.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  categoryVisual.icon,
                  size: 25,
                  color: categoryVisual.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(enabled: item.enabled),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              MoneyFormatter.signed(
                item.amountMinor,
                code: 'USD',
                negative: !isIncome,
              ),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScheduleCell(
                  icon: Icons.repeat_rounded,
                  label: 'Frequency',
                  value: _capitalize(item.frequency),
                ),
              ),
              Container(width: 1, height: 62, color: colors.outlineVariant),
              Expanded(
                child: _ScheduleCell(
                  icon: Icons.event_available_outlined,
                  label: 'Next occurrence',
                  value: _date(item.nextOccurrence),
                ),
              ),
            ],
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScheduleCell(
                  icon: Icons.calendar_today_outlined,
                  label: 'Start date',
                  value: _date(item.startDate),
                ),
              ),
              Container(width: 1, height: 62, color: colors.outlineVariant),
              Expanded(
                child: _ScheduleCell(
                  icon: Icons.all_inclusive_rounded,
                  label: 'End date',
                  value: item.endDate == null
                      ? 'No end date'
                      : _date(item.endDate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final success = FlowlySemanticColors.of(context).incomeForeground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.income.withValues(alpha: 0.10)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled
                ? Icons.check_circle_rounded
                : Icons.pause_circle_filled_rounded,
            size: 15,
            color: enabled ? success : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            enabled ? 'Active' : 'Paused',
            style: theme.textTheme.labelMedium?.copyWith(
              color: enabled ? success : colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Detail sections
// ------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _HistoryHeading extends StatelessWidget {
  const _HistoryHeading({required this.state, required this.onViewAll});

  final AsyncValue<List<Transaction>> state;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Payment history',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      if ((state.valueOrNull?.length ?? 0) > 3)
        TextButton.icon(
          onPressed: onViewAll,
          label: const Text('View all'),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
    ],
  );
}

class RecurringPaymentHistoryScreen extends ConsumerWidget {
  const RecurringPaymentHistoryScreen({super.key, required this.item});

  final RecurringTransaction item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(recurringCategoriesProvider);
    final state = item.id == null
        ? const AsyncData<List<Transaction>>([])
        : ref.watch(recurringPaymentHistoryProvider(item.id!));
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          AppLayout.safeScrollBottom(context),
        ),
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Actual transactions generated by this schedule.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _PaymentHistory(
            state: state,
            categories: categories,
            onRetry: item.id == null
                ? null
                : () =>
                      ref.invalidate(recurringPaymentHistoryProvider(item.id!)),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistory extends StatelessWidget {
  const _PaymentHistory({
    required this.state,
    required this.categories,
    required this.onRetry,
    this.limit,
  });

  final AsyncValue<List<Transaction>> state;
  final List<Category> categories;
  final VoidCallback? onRetry;
  final int? limit;

  @override
  Widget build(BuildContext context) => state.when(
    loading: () => Container(
      height: 96,
      alignment: Alignment.center,
      decoration: _surfaceDecoration(context),
      child: const CircularProgressIndicator(),
    ),
    error: (error, stack) => AppErrorState(
      title: "Couldn't load payment history",
      message: 'Please try again.',
      onRetry: onRetry ?? () {},
    ),
    data: (transactions) {
      if (transactions.isEmpty) {
        return const AppEmptyState(
          icon: Icons.history_rounded,
          title: 'No payments yet',
          message: 'Transactions generated by this recurring schedule will appear here.',
        );
      }
      final visible = limit == null
          ? transactions
          : transactions.take(limit!).toList(growable: false);
      return Container(
        decoration: _surfaceDecoration(context),
        child: Column(
          children: [
            for (var index = 0; index < visible.length; index++) ...[
              _PaymentHistoryRow(
                transaction: visible[index],
                categoryVisual: resolveCategoryVisual(
                  categories,
                  visible[index].category,
                  fallbackColor: visible[index].type == TransactionType.income
                      ? AppColors.income
                      : AppColors.expense,
                  fallbackIcon: Icons.category_outlined,
                ),
              ),
              if (index < visible.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: _DetailDivider(),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _PaymentHistoryRow extends StatelessWidget {
  const _PaymentHistoryRow({
    required this.transaction,
    required this.categoryVisual,
  });

  final Transaction transaction;
  final CategoryVisual categoryVisual;

  @override
  Widget build(BuildContext context) {
    final income = transaction.type == TransactionType.income;
    final semantic = FlowlySemanticColors.of(context);
    final amountColor = income
        ? semantic.incomeForeground
        : semantic.expenseForeground;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailsScreen(transaction: transaction),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: categoryVisual.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _month(transaction.date.month).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: categoryVisual.color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${transaction.date.day}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Automatic payment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  MoneyFormatter.signed(
                    transaction.amountMinor,
                    code: 'USD',
                    negative: !income,
                  ),
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _surfaceDecoration(BuildContext context, {double radius = 16}) {
  final colors = Theme.of(context).colorScheme;

  return BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colors.outlineVariant),
  );
}

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------

String _capitalize(String value) {
  if (value.isEmpty) return value;

  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _date(DateTime? value) {
  if (value == null) return 'None';

  const months = [
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
  ];

  return '${months[value.month - 1]} '
      '${value.day}, ${value.year}';
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
