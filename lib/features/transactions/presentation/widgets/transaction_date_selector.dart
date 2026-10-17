import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionDateSelector extends StatefulWidget {
  const TransactionDateSelector({
    super.key,
    required this.displayedMonth,
    required this.selectedDay,
    required this.allSelected,
    required this.transactionDays,
    required this.onAllSelected,
    required this.onDaySelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.activeRangeLabel,
  });

  final DateTime displayedMonth;
  final DateTime? selectedDay;
  final bool allSelected;
  final Set<DateTime> transactionDays;
  final VoidCallback onAllSelected;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final String? activeRangeLabel;

  @override
  State<TransactionDateSelector> createState() =>
      _TransactionDateSelectorState();
}

class _TransactionDateSelectorState extends State<TransactionDateSelector> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToRelevantDay();
  }

  @override
  void didUpdateWidget(covariant TransactionDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displayedMonth.year != widget.displayedMonth.year ||
        oldWidget.displayedMonth.month != widget.displayedMonth.month) {
      _scrollToRelevantDay();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToRelevantDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final now = DateTime.now();
      final selected = widget.selectedDay;
      final day = selected != null &&
              selected.year == widget.displayedMonth.year &&
              selected.month == widget.displayedMonth.month
          ? selected.day
          : now.year == widget.displayedMonth.year &&
                now.month == widget.displayedMonth.month
          ? now.day
          : 1;
      _controller.jumpTo(
        ((day - 1) * 52.0 - 40).clamp(
          0.0,
          _controller.position.maxScrollExtent,
        ).toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final daysInMonth = DateTime(
      widget.displayedMonth.year,
      widget.displayedMonth.month + 1,
      0,
    ).day;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(widget.displayedMonth),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.activeRangeLabel != null)
                      Text(
                        widget.activeRangeLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 64,
            child: Row(
              children: [
                _AllDateButton(
                  selected: widget.allSelected,
                  onTap: widget.onAllSelected,
                ),
                Container(
                  width: 1,
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  color: colors.outlineVariant,
                ),
                Expanded(
                  child: ListView.separated(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: daysInMonth,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (context, index) {
                      final day = DateTime(
                        widget.displayedMonth.year,
                        widget.displayedMonth.month,
                        index + 1,
                      );
                      return _DayButton(
                        day: day,
                        selected: _sameDay(widget.selectedDay, day),
                        hasTransactions: widget.transactionDays.contains(day),
                        onTap: () => widget.onDaySelected(day),
                      );
                    },
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

class _AllDateButton extends StatelessWidget {
  const _AllDateButton({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: 'Show all transaction dates',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Text(
            'All',
            style: TextStyle(
              color: selected ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.day,
    required this.selected,
    required this.hasTransactions,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool hasTransactions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      label: DateFormat('EEEE, MMMM d, yyyy').format(day),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('E').format(day).substring(0, 2),
                style: TextStyle(
                  color: selected
                      ? colors.onPrimary.withValues(alpha: .82)
                      : colors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasTransactions
                      ? selected
                            ? colors.onPrimary
                            : colors.primary
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime? first, DateTime second) =>
    first != null &&
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
