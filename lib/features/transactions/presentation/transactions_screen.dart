import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../../core/layout/app_layout.dart';
import '../../accounts/providers/account_provider.dart';
import '../domain/entities/transaction.dart';
import '../providers/transaction_provider.dart';
import 'transaction_details_screen.dart';
import 'transaction_filters_screen.dart';
import 'transaction_form_screen.dart';
import 'transaction_presentation.dart';
import 'widgets/transaction_card.dart';
import 'widgets/transaction_date_selector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({
    super.key,
    this.initialAccountId,
    this.initialCategory,
    this.initialMerchant,
    this.initialDateRange,
  });

  final int? initialAccountId;
  final String? initialCategory;
  final String? initialMerchant;
  final DateTimeRange? initialDateRange;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionFilterState _filters = const TransactionFilterState();
  bool _showSearch = false;
  final _searchController = TextEditingController();
  late DateTime _displayedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _filters = TransactionFilterState(
      selectedAccountIds: widget.initialAccountId != null
          ? {widget.initialAccountId!}
          : const {},
      selectedCategories: widget.initialCategory != null
          ? {widget.initialCategory!}
          : const {},
      dateRange: widget.initialDateRange,
      dateRangePreset: widget.initialDateRange == null ? null : 'custom',
    );
    if (widget.initialMerchant != null) {
      _searchController.text = widget.initialMerchant!;
      _showSearch = true;
    }
    final initialRange = widget.initialDateRange;
    _selectedDay = initialRange != null &&
            _isSameCalendarDay(initialRange.start, initialRange.end)
        ? _dateOnly(initialRange.start)
        : null;
    final initialMonth = _selectedDay ?? DateTime.now();
    _displayedMonth = DateTime(initialMonth.year, initialMonth.month);
    if (_selectedDay != null) {
      _filters = _filters.copyWith(dateRangePreset: () => 'day');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount => _filters.activeFilterCount;

  List<Transaction> _applyFilters(
    List<Transaction> items,
    List<dynamic> accounts,
    {bool includeDate = true,}
  ) {
    final term = _searchController.text.toLowerCase().trim();
    return items.where((item) {
      if (term.isNotEmpty) {
        final accountName = accounts
            .where((a) => a.id == item.accountId)
            .map((a) => a.name as String)
            .join();
        final text = '${item.title} ${item.notes} ${item.category} $accountName'
            .toLowerCase();
        if (!text.contains(term)) return false;
      }
      if (_filters.type != null && item.type != _filters.type) return false;
      if (_filters.status != null && item.status != _filters.status) {
        return false;
      }
      if (_filters.selectedAccountIds.isNotEmpty &&
          !_filters.selectedAccountIds.contains(item.accountId) &&
          !_filters.selectedAccountIds.contains(item.destinationAccountId)) {
        return false;
      }
      if (_filters.selectedCategories.isNotEmpty &&
          !_filters.selectedCategories.contains(item.category)) {
        return false;
      }
      if (_filters.source != null && item.source != _filters.source) {
        return false;
      }
      if (includeDate && _filters.dateRange != null) {
        final start = _dateOnly(_filters.dateRange!.start);
        final rawEnd = _dateOnly(_filters.dateRange!.end);
        final endExclusive = DateTime(rawEnd.year, rawEnd.month, rawEnd.day + 1);
        final transactionDate = item.date.toLocal();
        if (transactionDate.isBefore(start) ||
            !transactionDate.isBefore(endExclusive)) {
          return false;
        }
      }
      if (_filters.minimumAmount != null &&
          item.amountMinor < _filters.minimumAmount!) {
        return false;
      }
      if (_filters.maximumAmount != null &&
          item.amountMinor > _filters.maximumAmount!) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openFilters() async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<TransactionFilterState>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => TransactionFiltersScreen(initialFilter: _filters),
          ),
        );
    if (result != null && mounted) {
      setState(() {
        _filters = result;
        _selectedDay = result.dateRangePreset != 'custom' &&
                result.dateRange != null &&
                _isSameCalendarDay(
                  result.dateRange!.start,
                  result.dateRange!.end,
                )
            ? _dateOnly(result.dateRange!.start)
            : null;
        if (_selectedDay != null) {
          _displayedMonth = DateTime(
            _selectedDay!.year,
            _selectedDay!.month,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListProvider);
    final accounts = ref.watch(accountListProvider).value ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (_showSearch) _buildSearchBar(context),
            _buildTypePills(context),
            _buildDateSelector(context, state, accounts),
            Expanded(child: _buildBody(context, state, accounts)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(
    BuildContext context,
    AsyncValue<List<Transaction>> state,
    List<dynamic> accounts,
  ) {
    final relevantItems = _applyFilters(
      state.valueOrNull ?? const <Transaction>[],
      accounts,
      includeDate: false,
    );
    final transactionDays = relevantItems
        .map((item) => _dateOnly(item.date.toLocal()))
        .toSet();
    final range = _filters.dateRange;
    final customRangeLabel = range != null && _selectedDay == null
        ? '${DateFormat('MMM d, y').format(range.start)} - ${DateFormat('MMM d, y').format(range.end)}'
        : null;
    return TransactionDateSelector(
      displayedMonth: _displayedMonth,
      selectedDay: _selectedDay,
      allSelected: range == null,
      transactionDays: transactionDays,
      activeRangeLabel: customRangeLabel,
      onAllSelected: _showAllDates,
      onDaySelected: _selectDay,
      onPreviousMonth: () => setState(() {
        _displayedMonth = DateTime(
          _displayedMonth.year,
          _displayedMonth.month - 1,
        );
      }),
      onNextMonth: () => setState(() {
        _displayedMonth = DateTime(
          _displayedMonth.year,
          _displayedMonth.month + 1,
        );
      }),
    );
  }

  void _selectDay(DateTime day) {
    final localDay = _dateOnly(day);
    setState(() {
      _selectedDay = localDay;
      _filters = _filters.copyWith(
        dateRange: () => DateTimeRange(start: localDay, end: localDay),
        dateRangePreset: () => 'day',
      );
    });
  }

  void _showAllDates() {
    setState(() {
      _selectedDay = null;
      _filters = _filters.copyWith(
        dateRange: () => null,
        dateRangePreset: () => null,
      );
    });
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Transactions',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Search',
            icon: Icon(
              _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
              color: colors.onSurfaceVariant,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _searchController.clear();
              });
            },
          ),
          IconButton(
            tooltip: 'Filters',
            icon: Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount'),
              backgroundColor: colors.primary,
              textColor: colors.onPrimary,
              child: Icon(
                Icons.tune_rounded,
                color: _activeFilterCount > 0
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
            onPressed: _openFilters,
          ),
          IconButton(
            tooltip: 'Add transaction',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add, color: colors.onPrimary, size: 18),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: colors.onSurface),
        decoration: InputDecoration(
          hintText: 'Search title, notes, category…',
          hintStyle: TextStyle(color: colors.onSurfaceVariant),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colors.onSurfaceVariant,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => setState(() => _searchController.clear()),
                )
              : null,
          filled: true,
          fillColor: colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTypePills(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget pill(String label, TransactionType? value) {
      final selected = _filters.type == value;
      return GestureDetector(
        onTap: () => setState(() {
          _filters = _filters.copyWith(type: () => value);
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          pill('All', null),
          const SizedBox(width: 8),
          pill('Income', TransactionType.income),
          const SizedBox(width: 8),
          pill('Expense', TransactionType.expense),
          const SizedBox(width: 8),
          pill('Transfer', TransactionType.transfer),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<Transaction>> state,
    List<dynamic> accounts,
  ) {
    return state.when(
      loading: () => const AppLoadingList(),
      error: (error, _) => AppErrorState(
        title: 'Something went wrong',
        message: "We couldn't load your transactions.",
        onRetry: () => ref.invalidate(transactionListProvider),
      ),
      data: (items) {
        final filtered = _applyFilters(items, accounts);
        if (filtered.isEmpty) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(transactionListProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * .62,
                  child: AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _selectedDay != null
                        ? 'No transactions on this day'
                        : _searchController.text.isNotEmpty ||
                              _activeFilterCount > 0
                        ? 'No matches found'
                        : 'No transactions yet.',
                    message: _selectedDay != null
                        ? 'No transactions were recorded for the selected date.'
                        : _searchController.text.isNotEmpty ||
                              _activeFilterCount > 0
                        ? 'Try adjusting your search or filters.'
                        : 'Add one manually, or turn on automatic detection.',
                    actionLabel: _selectedDay != null
                        ? 'Show All Dates'
                        : _searchController.text.isEmpty &&
                              _activeFilterCount == 0
                        ? 'Add transaction'
                        : null,
                    onAction: _selectedDay != null
                        ? _showAllDates
                        : _searchController.text.isEmpty &&
                              _activeFilterCount == 0
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionFormScreen(),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        }

        final groups = <DateTime, List<Transaction>>{};
        for (final t in filtered) {
          final day = DateTime(t.date.year, t.date.month, t.date.day);
          groups.putIfAbsent(day, () => []).add(t);
        }
        for (final dayItems in groups.values) {
          dayItems.sort(compareTransactionsByCreatedAtDescending);
        }
        final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

        return RefreshIndicator(
          onRefresh: () => ref.read(transactionListProvider.notifier).refresh(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              AppLayout.scrollContentGap,
            ),
            itemCount: days.length,
            itemBuilder: (context, i) {
              final day = days[i];
              final dayItems = groups[day]!;
              return _buildDayGroup(context, day, dayItems);
            },
          ),
        );
      },
    );
  }

  Widget _buildDayGroup(
    BuildContext context,
    DateTime day,
    List<Transaction> items,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (day == today) {
      label = 'Today';
    } else if (day == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, yyyy').format(day);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
        ),
        ...items.map(
          (item) => TransactionCard(
            transaction: item,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionDetailsScreen(transaction: item),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool _isSameCalendarDay(DateTime first, DateTime second) {
  final firstLocal = first.toLocal();
  final secondLocal = second.toLocal();
  return firstLocal.year == secondLocal.year &&
      firstLocal.month == secondLocal.month &&
      firstLocal.day == secondLocal.day;
}
