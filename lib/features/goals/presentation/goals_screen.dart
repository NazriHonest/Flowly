import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../domain/entities/goal.dart';
import '../providers/goal_provider.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/theme/app_colors.dart';
import 'goal_details_screen.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GoalFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add goal'),
      ),
      body: state.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(
          title: 'Couldn’t load goals',
          message: 'Please try again.',
          onRetry: () => ref.invalidate(goalListProvider),
        ),
        data: (goals) => goals.isEmpty
            ? AppEmptyState(
                icon: Icons.flag_outlined,
                title: 'Start a savings goal',
                message: 'Set a target and make steady progress toward it.',
                actionLabel: 'Add goal',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalFormScreen()),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemCount: goals.length,
                itemBuilder: (_, index) {
                  final goal = goals[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: CircleAvatar(
                        child: const Icon(Icons.flag_outlined),
                      ),
                      title: Text(
                        goal.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: goal.progress.clamp(0, 1),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${MoneyFormatter.format(goal.currentMinor)} saved · ${MoneyFormatter.format((goal.targetMinor - goal.currentMinor).clamp(0, goal.targetMinor))} remaining',
                            ),
                          ],
                        ),
                      ),
                      trailing: Text('${(goal.progress * 100).round()}%'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GoalDetailsScreen(goal: goal),
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

/* Legacy Goal Details implementation moved to goal_details_screen.dart.
class _LegacyGoalDetailsScreen extends ConsumerWidget {
  const _LegacyGoalDetailsScreen({super.key, required this.goal});
  final Goal goal;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref
            .watch(goalListProvider)
            .valueOrNull
            ?.where((item) => item.id == goal.id)
            .firstOrNull ??
        goal;
    return Scaffold(
      appBar: AppBar(title: Text(current.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Edit goal',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalFormScreen(goal: current),
                ),
              ),
            ),
          ),
          FlowlySurface(
            child: Column(children: [
              SizedBox(width: 126, height: 126, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: current.progress.clamp(0, 1), strokeWidth: 10), Text('${(current.progress * 100).round()}%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))])),
              const SizedBox(height: 16),
              Text(current.name, style: Theme.of(context).textTheme.titleLarge),
            ]),
          ),
          const SizedBox(height: 16),
          Center(child: Text('Target ${MoneyFormatter.format(current.targetMinor)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          Center(child: Text('${MoneyFormatter.format(current.currentMinor)} saved · ${MoneyFormatter.format((current.targetMinor - current.currentMinor).clamp(0, current.targetMinor))} remaining')),
          if (current.targetDate != null)
            Text(
              'Target date: ${current.targetDate!.toLocal().toString().split(' ').first}',
            ),
          Text(
            'Remaining: ${MoneyFormatter.format((current.targetMinor - current.currentMinor).clamp(0, current.targetMinor))}',
          ),
          const SizedBox(height: 20),
          Text(
            'Contribution history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          FutureBuilder<List<Map<String, Object?>>>(
            future: AppDatabase.instance.goalContributions(current.id!),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const [];
              if (entries.isEmpty)
                return const ListTile(title: Text('No contributions yet.'));
              return Column(
                children: entries
                    .map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add_circle_outline),
                        title: Text(
                          MoneyFormatter.format(entry['amount'] as int),
                        ),
                        subtitle: Text(
                          (entry['contributed_at'] as String).split('T').first,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add contribution'),
            onPressed: () => _contribute(context, ref),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete goal'),
            onPressed: () async {
              if (!await showFlowlyConfirmation(context, title: 'Delete goal?', message: 'This permanently removes the goal and its contribution history.', confirmLabel: 'Delete goal')) return;
              await ref.read(goalListProvider.notifier).delete(current.id!);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _contribute(BuildContext context, WidgetRef ref) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ContributionScreen(goal: goal)));
  }
}

}
*/

class ContributionScreen extends ConsumerStatefulWidget {
  const ContributionScreen({super.key, required this.goal});
  final Goal goal;
  @override
  ConsumerState<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends ConsumerState<ContributionScreen> {
  final amount = TextEditingController();
  final notes = TextEditingController();
  DateTime date = DateTime.now();
  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add contribution')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: const Icon(Icons.savings_outlined),
                ),
                title: Text(
                  widget.goal.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: LinearProgressIndicator(
                  value: widget.goal.progress.clamp(0, 1),
                ),
                trailing: Text('${(widget.goal.progress * 100).round()}%'),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'CONTRIBUTION AMOUNT',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextField(
              controller: amount,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.income,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                prefixText: r'$ ',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: Theme.of(context).inputDecorationTheme.fillColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(
                MaterialLocalizations.of(context).formatMediumDate(date),
              ),
              onTap: () async {
                final next = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDate: date,
                );
                if (next != null) setState(() => date = next);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional',
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(amount.text);
                if (value == null || value <= 0) return;
                await ref
                    .read(goalListProvider.notifier)
                    .contribute(widget.goal.id!, (value * 100).round());
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Add Contribution'),
            ),
          ],
        ),
      ),
    ),
  );
}

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.goal});
  final Goal? goal;
  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.goal?.name ?? '');
  late final target = TextEditingController(
    text: widget.goal == null
        ? ''
        : (widget.goal!.targetMinor / 100).toStringAsFixed(2),
  );
  late final starting = TextEditingController(
    text: widget.goal == null
        ? ''
        : (widget.goal!.currentMinor / 100).toStringAsFixed(2),
  );
  DateTime? targetDate;
  int selectedIcon = Icons.savings_outlined.codePoint;
  int selectedColor = AppColors.primary.toARGB32();
  static const _icons = [
    Icons.savings_outlined,
    Icons.home_outlined,
    Icons.flight_takeoff_outlined,
    Icons.card_giftcard_outlined,
    Icons.favorite_border,
    Icons.flag_outlined,
    Icons.school_outlined,
    Icons.directions_car_outlined,
  ];

  @override
  void initState() {
    super.initState();
    targetDate = widget.goal?.targetDate;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.goal == null ? 'Add goal' : 'Edit goal')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Goal name',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: name,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            validator: (value) => (value ?? '').isEmpty ? 'Enter a name' : null,
          ),
          const SizedBox(height: 18),
          Text(
            'Target amount',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.payments_outlined),
              prefixText: r'$ ',
            ),
            validator: (value) =>
                double.tryParse(value ?? '') == null ? 'Enter an amount' : null,
          ),
          const SizedBox(height: 18),
          Text(
            'Starting amount',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: starting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              prefixText: r'$ ',
            ),
            validator: (value) =>
                value != null &&
                    value.isNotEmpty &&
                    double.tryParse(value) == null
                ? 'Enter a valid amount'
                : null,
          ),
          const SizedBox(height: 18),
          Text(
            'Target date',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ListTile(
            tileColor: Theme.of(context).inputDecorationTheme.fillColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: EdgeInsets.zero,
            title: const Text('Target date'),
            subtitle: Text(
              targetDate == null
                  ? 'No target date'
                  : targetDate!.toLocal().toString().split(' ').first,
            ),
            trailing: targetDate == null
                ? const Icon(Icons.calendar_today_outlined)
                : IconButton(
                    tooltip: 'Clear target date',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => targetDate = null),
                  ),
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: targetDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (selected != null && mounted) {
                setState(() => targetDate = selected);
              }
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Icon',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons
                .map(
                  (icon) => ChoiceChip(
                    label: Icon(icon),
                    selected: selectedIcon == icon.codePoint,
                    onSelected: (_) =>
                        setState(() => selectedIcon = icon.codePoint),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Text(
            'Colour',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppColors.identityPalette
                .map((tone) => tone.toARGB32())
                .map(
                  (color) => InkWell(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == color
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: selectedColor == color
                          ? const Icon(
                              Icons.check,
                              color: AppColors.onPrimary,
                              size: 17,
                            )
                          : null,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _save,
            child: Text(widget.goal == null ? 'Save goal' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    await ref
        .read(goalListProvider.notifier)
        .save(
          Goal(
            id: widget.goal?.id,
            name: name.text.trim(),
            targetMinor: (double.parse(target.text) * 100).round(),
            currentMinor: starting.text.trim().isEmpty
                ? widget.goal?.currentMinor ?? 0
                : (double.parse(starting.text) * 100).round(),
            targetDate: targetDate,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    name.dispose();
    target.dispose();
    starting.dispose();
    super.dispose();
  }
}
