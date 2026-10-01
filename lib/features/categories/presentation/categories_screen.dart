import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../domain/entities/category.dart';
import '../providers/category_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: categories.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(
          title: 'Couldn’t load categories',
          message: 'Please try again.',
          onRetry: () => ref.invalidate(categoryListProvider),
        ),
        data: (items) => items.isEmpty
      ? AppEmptyState(
          icon: Icons.category_outlined,
          title: 'No categories yet',
          message: 'Create categories to organize your spending.',
          actionLabel: 'Add category',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
          ),
        )
      : ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final category = items[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                leading: CircleAvatar(
                  backgroundColor: Color(category.color),
                  child: Icon(
                    IconData(category.icon, fontFamily: 'MaterialIcons'),
                    color: AppColors.onPrimary,
                  ),
                ),
                title: Text(category.name),
                subtitle: Text(category.type),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CategoryDetailsScreen(category: category),
                  ),
                ),
              ),
            );
          },
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
    final related =
        (ref.watch(transactionListProvider).valueOrNull ??
                const <Transaction>[])
            .where(
              (item) =>
                  item.category == category.name &&
                  item.status == ReviewStatus.confirmed,
            )
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryFormScreen(category: category),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(category.color).withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconData(category.icon, fontFamily: 'MaterialIcons'),
              size: 32,
              color: Color(category.color),
            ),
          ),
          const SizedBox(height: 20),
          Text(category.name, style: Theme.of(context).textTheme.headlineSmall),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Applicability'),
            subtitle: Text(category.type),
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
          ...related
              .take(5)
              .map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(
                      IconData(category.icon, fontFamily: 'MaterialIcons'),
                      size: 17,
                    ),
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    item.date.toLocal().toString().split(' ').first,
                  ),
                  trailing: Text(MoneyFormatter.format(item.amountMinor)),
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
                  .archive(category.id!);
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
        padding: const EdgeInsets.all(20),
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
      await ref
          .read(categoryListProvider.notifier)
          .save(
            Category(
              id: widget.category?.id,
              name: _name.text.trim(),
              icon: _icon,
              color: _color,
              type: _type,
            ),
          );
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
