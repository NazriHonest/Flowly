import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../accounts/domain/entities/account.dart';
import '../../accounts/providers/account_provider.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/providers/category_provider.dart';
import '../domain/entities/transaction.dart';

class TransactionFilterState {
  const TransactionFilterState({
    this.type,
    this.status,
    this.selectedAccountIds = const {},
    this.selectedCategories = const {},
    this.source,
    this.dateRange,
    this.dateRangePreset,
    this.minimumAmount,
    this.maximumAmount,
  });

  final TransactionType? type;
  final ReviewStatus? status;
  final Set<int> selectedAccountIds;
  final Set<String> selectedCategories;
  final TransactionSource? source;
  final DateTimeRange? dateRange;
  final String? dateRangePreset; // 'today', '7days', 'thisMonth', 'custom'
  final int? minimumAmount; // in minor units
  final int? maximumAmount; // in minor units

  int get activeFilterCount {
    int count = 0;
    if (type != null) count++;
    if (status != null) count++;
    if (selectedAccountIds.isNotEmpty) count++;
    if (selectedCategories.isNotEmpty) count++;
    if (source != null) count++;
    if (dateRange != null || dateRangePreset != null) count++;
    if (minimumAmount != null) count++;
    if (maximumAmount != null) count++;
    return count;
  }

  TransactionFilterState copyWith({
    TransactionType? Function()? type,
    ReviewStatus? Function()? status,
    Set<int>? selectedAccountIds,
    Set<String>? selectedCategories,
    TransactionSource? Function()? source,
    DateTimeRange? Function()? dateRange,
    String? Function()? dateRangePreset,
    int? Function()? minimumAmount,
    int? Function()? maximumAmount,
  }) {
    return TransactionFilterState(
      type: type != null ? type() : this.type,
      status: status != null ? status() : this.status,
      selectedAccountIds: selectedAccountIds ?? this.selectedAccountIds,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      source: source != null ? source() : this.source,
      dateRange: dateRange != null ? dateRange() : this.dateRange,
      dateRangePreset: dateRangePreset != null
          ? dateRangePreset()
          : this.dateRangePreset,
      minimumAmount: minimumAmount != null
          ? minimumAmount()
          : this.minimumAmount,
      maximumAmount: maximumAmount != null
          ? maximumAmount()
          : this.maximumAmount,
    );
  }
}

class TransactionFiltersScreen extends ConsumerStatefulWidget {
  const TransactionFiltersScreen({super.key, required this.initialFilter});

  final TransactionFilterState initialFilter;

  @override
  ConsumerState<TransactionFiltersScreen> createState() =>
      _TransactionFiltersScreenState();
}

class _TransactionFiltersScreenState
    extends ConsumerState<TransactionFiltersScreen> {
  late TransactionType? _type;
  late ReviewStatus? _status;
  late Set<int> _selectedAccountIds;
  late Set<String> _selectedCategories;
  late TransactionSource? _source;
  late DateTimeRange? _dateRange;
  late String? _dateRangePreset;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _type = widget.initialFilter.type;
    _status = widget.initialFilter.status;
    _selectedAccountIds = Set<int>.from(
      widget.initialFilter.selectedAccountIds,
    );
    _selectedCategories = Set<String>.from(
      widget.initialFilter.selectedCategories,
    );
    _source = widget.initialFilter.source;
    _dateRange = widget.initialFilter.dateRange;
    _dateRangePreset = widget.initialFilter.dateRangePreset;

    _minController = TextEditingController(
      text: widget.initialFilter.minimumAmount != null
          ? (widget.initialFilter.minimumAmount! / 100).toStringAsFixed(0)
          : '',
    );
    _maxController = TextEditingController(
      text: widget.initialFilter.maximumAmount != null
          ? (widget.initialFilter.maximumAmount! / 100).toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  TransactionFilterState _buildCurrentState() {
    final minVal = double.tryParse(_minController.text.trim());
    final maxVal = double.tryParse(_maxController.text.trim());

    return TransactionFilterState(
      type: _type,
      status: _status,
      selectedAccountIds: _selectedAccountIds,
      selectedCategories: _selectedCategories,
      source: _source,
      dateRange: _dateRange,
      dateRangePreset: _dateRangePreset,
      minimumAmount: minVal != null && minVal > 0
          ? (minVal * 100).round()
          : null,
      maximumAmount: maxVal != null && maxVal > 0
          ? (maxVal * 100).round()
          : null,
    );
  }

  void _clearAll() {
    setState(() {
      _type = null;
      _status = null;
      _selectedAccountIds.clear();
      _selectedCategories.clear();
      _source = null;
      _dateRange = null;
      _dateRangePreset = null;
      _minController.clear();
      _maxController.clear();
    });
  }

  void _applyAndClose() {
    Navigator.pop(context, _buildCurrentState());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFCAD7D3);
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    final accounts = ref.watch(accountListProvider).value ?? [];
    final categories = ref.watch(categoryListProvider).value ?? [];
    final activeCount = _buildCurrentState().activeFilterCount;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            if (activeCount > 0)
              Text(
                '$activeCount active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _clearAll,
            child: const Text(
              'Clear All',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2ECE9),
              ),
            ),
          ),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _applyAndClose,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // Section: Date range
          _buildSectionHeader('Date range', textSecondary),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildThemeChip('Today', _dateRangePreset == 'today', () {
                  final now = DateTime.now();
                  setState(() {
                    if (_dateRangePreset == 'today') {
                      _dateRangePreset = null;
                      _dateRange = null;
                    } else {
                      _dateRangePreset = 'today';
                      _dateRange = DateTimeRange(
                        start: DateTime(now.year, now.month, now.day),
                        end: now,
                      );
                    }
                  });
                }),
                const SizedBox(width: 8),
                _buildThemeChip('7 days', _dateRangePreset == '7days', () {
                  final now = DateTime.now();
                  setState(() {
                    if (_dateRangePreset == '7days') {
                      _dateRangePreset = null;
                      _dateRange = null;
                    } else {
                      _dateRangePreset = '7days';
                      _dateRange = DateTimeRange(
                        start: now.subtract(const Duration(days: 7)),
                        end: now,
                      );
                    }
                  });
                }),
                const SizedBox(width: 8),
                _buildThemeChip(
                  'This month',
                  _dateRangePreset == 'thisMonth',
                  () {
                    final now = DateTime.now();
                    setState(() {
                      if (_dateRangePreset == 'thisMonth') {
                        _dateRangePreset = null;
                        _dateRange = null;
                      } else {
                        _dateRangePreset = 'thisMonth';
                        _dateRange = DateTimeRange(
                          start: DateTime(now.year, now.month, 1),
                          end: now,
                        );
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildThemeChip(
                  'Custom',
                  _dateRangePreset == 'custom',
                  () async {
                    final value = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: _dateRange,
                    );
                    if (value != null) {
                      setState(() {
                        _dateRangePreset = 'custom';
                        _dateRange = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Section: Accounts
          _buildSectionHeader('Accounts', textSecondary),
          const SizedBox(height: 10),
          _buildSelectorCard(
            context: context,
            icon: Icons.account_balance_wallet_outlined,
            title: _accountsLabel(accounts),
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            textPrimary: textPrimary,
            onTap: () => _openAccountsSheet(context, accounts),
          ),
          const SizedBox(height: 22),

          // Section: Categories
          _buildSectionHeader('Categories', textSecondary),
          const SizedBox(height: 10),
          _buildSelectorCard(
            context: context,
            icon: Icons.sell_outlined,
            title: _categoriesLabel(categories),
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            textPrimary: textPrimary,
            onTap: () => _openCategoriesSheet(context, categories),
          ),
          const SizedBox(height: 22),

          // Section: Transaction type
          _buildSectionHeader('Transaction type', textSecondary),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildThemeChip(
                'All',
                _type == null,
                () => setState(() => _type = null),
              ),
              _buildThemeChip(
                'Income',
                _type == TransactionType.income,
                () => setState(() => _type = TransactionType.income),
              ),
              _buildThemeChip(
                'Expense',
                _type == TransactionType.expense,
                () => setState(() => _type = TransactionType.expense),
              ),
              _buildThemeChip(
                'Transfer',
                _type == TransactionType.transfer,
                () => setState(() => _type = TransactionType.transfer),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Section: Source
          _buildSectionHeader('Source', textSecondary),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildThemeChip(
                  'Auto',
                  _source == TransactionSource.smsLive,
                  () => setState(() {
                    _source = _source == TransactionSource.smsLive
                        ? null
                        : TransactionSource.smsLive;
                  }),
                ),
                const SizedBox(width: 8),
                _buildThemeChip(
                  'Manual',
                  _source == TransactionSource.manual,
                  () => setState(() {
                    _source = _source == TransactionSource.manual
                        ? null
                        : TransactionSource.manual;
                  }),
                ),
                const SizedBox(width: 8),
                _buildThemeChip(
                  'Imported',
                  _source == TransactionSource.smsImport,
                  () => setState(() {
                    _source = _source == TransactionSource.smsImport
                        ? null
                        : TransactionSource.smsImport;
                  }),
                ),
                const SizedBox(width: 8),
                _buildThemeChip(
                  'Recurring',
                  _source == TransactionSource.recurring,
                  () => setState(() {
                    _source = _source == TransactionSource.recurring
                        ? null
                        : TransactionSource.recurring;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Section: Review status
          _buildSectionHeader('Review status', textSecondary),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildThemeChip(
                'All',
                _status == null,
                () => setState(() => _status = null),
              ),
              _buildThemeChip(
                'Needs review',
                _status == ReviewStatus.needsReview,
                () => setState(() => _status = ReviewStatus.needsReview),
              ),
              _buildThemeChip(
                'Confirmed',
                _status == ReviewStatus.confirmed,
                () => setState(() => _status = ReviewStatus.confirmed),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Section: Min & Max amount
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Min amount', textSecondary),
                    const SizedBox(height: 10),
                    _buildAmountField(
                      controller: _minController,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      hint: '0',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Max amount', textSecondary),
                    const SizedBox(height: 10),
                    _buildAmountField(
                      controller: _maxController,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      hint: '500',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildThemeChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;
    final bg = isSelected
        ? primary
        : (isDark ? const Color(0xFF142421) : Colors.white);
    final borderColor = isSelected
        ? primary
        : (isDark ? const Color(0xFF2D4540) : const Color(0xFFCAD7D3));
    final textColor = isSelected
        ? Colors.white
        : (isDark ? const Color(0xFFD4E2DE) : const Color(0xFF1E2E2B));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.32),
                      blurRadius: 7,
                      offset: const Offset(0, 2.5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.2)
                          : const Color(0x12000000),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : const Color(0x0E000000),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isDark
                    ? const Color(0xFF9EBFB8)
                    : const Color(0xFF4A635D),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark
                    ? const Color(0xFF9EBFB8)
                    : const Color(0xFF4A635D),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField({
    required TextEditingController controller,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required String hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0x0E000000),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        decoration: InputDecoration(
          prefixText: '\$ ',
          prefixStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF5E7974) : const Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  String _accountsLabel(List<Account> accounts) {
    if (_selectedAccountIds.isEmpty) return 'All accounts';
    if (_selectedAccountIds.length == 1) {
      final acc = accounts
          .where((a) => a.id == _selectedAccountIds.first)
          .firstOrNull;
      return acc?.name ?? '1 selected';
    }
    return '${_selectedAccountIds.length} selected';
  }

  String _categoriesLabel(List<Category> categories) {
    if (_selectedCategories.isEmpty) return 'All categories';
    if (_selectedCategories.length <= 2) {
      return _selectedCategories.join(', ');
    }
    return '${_selectedCategories.length} selected';
  }

  void _openAccountsSheet(BuildContext context, List<Account> accounts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Select Accounts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              setState(() {
                                if (_selectedAccountIds.length ==
                                    accounts.length) {
                                  _selectedAccountIds.clear();
                                } else {
                                  _selectedAccountIds = accounts
                                      .where((a) => a.id != null)
                                      .map((a) => a.id!)
                                      .toSet();
                                }
                              });
                            });
                          },
                          child: Text(
                            _selectedAccountIds.length == accounts.length
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      height: 16,
                      color: isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFE2ECE9),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          final isSelected =
                              account.id != null &&
                              _selectedAccountIds.contains(account.id);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              account.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              account.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            activeColor: AppColors.primary,
                            value: isSelected,
                            onChanged: (checked) {
                              if (account.id == null) return;
                              setModalState(() {
                                setState(() {
                                  if (checked == true) {
                                    _selectedAccountIds.add(account.id!);
                                  } else {
                                    _selectedAccountIds.remove(account.id!);
                                  }
                                });
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCategoriesSheet(BuildContext context, List<Category> categories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = categories.where((c) {
              return searchQuery.isEmpty ||
                  c.name.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Select Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              setState(() {
                                if (_selectedCategories.length ==
                                    categories.length) {
                                  _selectedCategories.clear();
                                } else {
                                  _selectedCategories = categories
                                      .map((c) => c.name)
                                      .toSet();
                                }
                              });
                            });
                          },
                          child: Text(
                            _selectedCategories.length == categories.length
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (v) => setModalState(() => searchQuery = v),
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search categories...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    Divider(
                      height: 16,
                      color: isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFE2ECE9),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final category = filtered[index];
                          final isSelected = _selectedCategories.contains(
                            category.name,
                          );
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(category.color)
                                  .withValues(alpha: 0.16),
                              child: Icon(
                                IconData(
                                  category.icon,
                                  fontFamily: 'MaterialIcons',
                                ),
                                size: 16,
                                color: Color(category.color),
                              ),
                            ),
                            title: Text(
                              category.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            activeColor: AppColors.primary,
                            value: isSelected,
                            onChanged: (checked) {
                              setModalState(() {
                                setState(() {
                                  if (checked == true) {
                                    _selectedCategories.add(category.name);
                                  } else {
                                    _selectedCategories.remove(category.name);
                                  }
                                });
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
