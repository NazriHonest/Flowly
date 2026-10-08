import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../../core/layout/app_layout.dart';
import '../domain/entities/category.dart';
import '../providers/category_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../../core/theme/app_colors.dart';
import '../../budgets/providers/budget_provider.dart';
import '../../categorization/providers/merchant_rule_provider.dart';
import '../../recurring/providers/recurring_provider.dart';
import '../../transactions/presentation/transaction_details_screen.dart';
import '../../transactions/presentation/widgets/transaction_card.dart';


class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: _CategoryTabBar(),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openCategoryForm(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add category'),
        ),
        body: categories.when(
          loading: () => const AppLoadingList(),
          error: (error, _) => AppErrorState(
            title: 'Couldn’t load categories',
            message: 'Please try again.',
            onRetry: () => ref.invalidate(categoryListProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return AppEmptyState(
                icon: Icons.category_outlined,
                title: 'No categories yet',
                message: 'Create income and expense categories to organize your transactions.',
                actionLabel: 'Add category',
                onAction: () => _openCategoryForm(context),
              );
            }

            final expenseCategories = items
                .where((category) => category.type.toLowerCase() == 'expense')
                .toList();

            final incomeCategories = items
                .where((category) => category.type.toLowerCase() == 'income')
                .toList();

            return TabBarView(
              children: [
                _CategoryList(
                  categories: expenseCategories,
                  type: _CategoryTabType.expense,
                  onAddCategory: () => _openCategoryForm(context),
                ),
                _CategoryList(
                  categories: incomeCategories,
                  type: _CategoryTabType.income,
                  onAddCategory: () => _openCategoryForm(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openCategoryForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
    );
  }
}

class _CategoryTabBar extends StatelessWidget {
  const _CategoryTabBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelPadding: EdgeInsets.zero,
        labelColor: colors.onSurface,
        unselectedLabelColor: colors.onSurfaceVariant,
        tabs: const [
          _CategoryTab(
            icon: Icons.north_east_rounded,
            label: 'Expense',
            color: AppColors.expense,
          ),
          _CategoryTab(
            icon: Icons.south_west_rounded,
            label: 'Income',
            color: AppColors.income,
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

enum _CategoryTabType { expense, income }

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.type,
    required this.onAddCategory,
  });

  final List<dynamic> categories;
  final _CategoryTabType type;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return _CategoryTypeEmptyState(type: type, onAddCategory: onAddCategory);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        AppLayout.safeScrollBottom(context, hasFloatingActionButton: true),
      ),
      itemCount: categories.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CategoryListHeader(type: type, count: categories.length),
          );
        }

        final category = categories[index - 1];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CategoryCard(
            category: category,
            type: type,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryDetailsScreen(category: category),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryListHeader extends StatelessWidget {
  const _CategoryListHeader({required this.type, required this.count});

  final _CategoryTabType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isExpense = type == _CategoryTabType.expense;

    final title = isExpense ? 'Expense categories' : 'Income categories';

    final description = isExpense
        ? 'Organize where your money is spent.'
        : 'Organize where your money comes from.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _CountBadge(count: count),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.type,
    required this.onTap,
  });

  final dynamic category;
  final _CategoryTabType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final categoryColor = Color(category.color);

    return Material(
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
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  IconData(category.icon, fontFamily: 'MaterialIcons'),
                  color: categoryColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTypeEmptyState extends StatelessWidget {
  const _CategoryTypeEmptyState({
    required this.type,
    required this.onAddCategory,
  });

  final _CategoryTabType type;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isExpense = type == _CategoryTabType.expense;

    final color = isExpense ? AppColors.expense : AppColors.income;

    final icon = isExpense
        ? Icons.north_east_rounded
        : Icons.south_west_rounded;

    final title = isExpense ? 'No expense categories' : 'No income categories';

    final message = isExpense
        ? 'Create an expense category to organize your spending.'
        : 'Create an income category to organize your earnings.';

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          32,
          32,
          32,
          AppLayout.safeScrollBottom(context, hasFloatingActionButton: true),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddCategory,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add category'),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryDetailsScreen extends ConsumerWidget {
  const CategoryDetailsScreen({super.key, required this.category});
  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = category.id == null
        ? category
        : ref.watch(categoryByIdProvider(category.id!)) ?? category;
    final related =
        (ref.watch(transactionListProvider).valueOrNull ??
                const <Transaction>[])
            .where(
              (item) =>
                  item.category == current.name &&
                  item.status == ReviewStatus.confirmed,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryFormScreen(category: current),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          AppLayout.safeScrollBottom(context),
        ),
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(current.color).withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconData(current.icon, fontFamily: 'MaterialIcons'),
              size: 32,
              color: Color(current.color),
            ),
          ),
          const SizedBox(height: 20),
          Text(current.name, style: Theme.of(context).textTheme.headlineSmall),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Applicability'),
            subtitle: Text(current.type),
          ),
          const SizedBox(height: 12),
          Text(
            'Recent transactions',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (related.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('No transactions in this category yet.'),
            ),
          const SizedBox(height: 10),
          ...related.take(5).map(
            (item) => TransactionCard(
              transaction: item,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TransactionDetailsScreen(transaction: item),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive category'),
            onPressed: () async {
              if (!await showFlowlyConfirmation(
                context,
                title: 'Archive category?',
                message: 'Existing transactions will retain this category.',
                confirmLabel: 'Archive category',
              )) {
                return;
              }
              await ref
                  .read(categoryListProvider.notifier)
                  .archive(current.id!);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.category});
  final Category? category;
  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late String _type = widget.category?.type ?? 'expense';
  late int _color = widget.category?.color ?? AppColors.primary.toARGB32();
  late int _icon = widget.category?.icon ?? Icons.category.codePoint;
  static const _icons = [
    Icons.category,
    Icons.shopping_basket,
    Icons.restaurant,
    Icons.wifi,
    Icons.directions_car,
    Icons.receipt_long,
    Icons.payments,
    Icons.favorite,
  ];
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.category == null ? 'Add category' : 'Edit category'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          AppLayout.safeScrollBottom(context),
        ),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter a category name' : null,
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Expense')),
              ButtonSegment(value: 'income', label: Text('Income')),
            ],
            selected: {_type == 'both' ? 'expense' : _type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 20),
          const Text('Icon', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: _icons
                .map(
                  (icon) => ChoiceChip(
                    label: Icon(icon),
                    selected: _icon == icon.codePoint,
                    onSelected: (_) => setState(() => _icon = icon.codePoint),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text('Colour', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: AppColors.identityPalette
                .map((tone) => tone.toARGB32())
                .map(
                  (color) => ChoiceChip(
                    label: const Text(''),
                    selected: _color == color,
                    avatar: CircleAvatar(backgroundColor: Color(color)),
                    onSelected: (_) => setState(() => _color = color),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _save,
            child: Text(
              widget.category == null ? 'Save category' : 'Save changes',
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final name = _name.text.trim();
      final categoryWasRenamed =
          widget.category != null && widget.category!.name != name;
      await ref
          .read(categoryListProvider.notifier)
          .save(
            Category(
              id: widget.category?.id,
              name: name,
              icon: _icon,
              color: _color,
              type: _type,
            ),
          );
      if (categoryWasRenamed) {
        await Future.wait([
          ref.read(transactionListProvider.notifier).refresh(),
          ref.read(budgetListProvider.notifier).refresh(),
          ref.read(recurringListProvider.notifier).refresh(),
          ref.read(merchantRuleListProvider.notifier).refresh(),
        ]);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A category with that name already exists.'),
          ),
        );
      }
    }
  }
}
