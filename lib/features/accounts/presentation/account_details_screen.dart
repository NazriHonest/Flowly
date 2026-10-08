import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/presentation/widgets/transaction_card.dart';
import '../domain/entities/account.dart';
import '../domain/services/account_balance_calculator.dart';
import '../providers/account_provider.dart';
import 'add_account_screen.dart';

class AccountDetailsScreen extends ConsumerWidget {
  const AccountDetailsScreen({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(transactionListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.onSurface),
        title: Text(
          account.name,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddAccountScreen(account: account),
              ),
            ),
          ),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              Icons.archive_outlined,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            onPressed: () async {
              if (!await showFlowlyConfirmation(
                context,
                title: 'Archive account?',
                message: 'Archived accounts are hidden from new transactions but remain in your history.',
                confirmLabel: 'Archive account',
              )) {
                return;
              }
              await ref.read(accountListProvider.notifier).archive(account.id!);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: state.when(
        loading: () => const AppLoadingList(),
        error: (e, _) => AppErrorState(
          title: "Couldn't load account",
          message: 'Your transactions are still safe. Please try again.',
          onRetry: () => ref.invalidate(transactionListProvider),
        ),
        data: (all) {
          final items = all
              .where(
                (t) =>
                    (t.accountId == account.id ||
                        (t.type == TransactionType.transfer &&
                            t.destinationAccountId == account.id)) &&
                    t.status == ReviewStatus.confirmed,
              )
              .toList();
          final balance = AccountBalanceCalculator.current(account, all);
          final recent = items.take(10).toList();
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Hero card ─────────────────────────────────────────────
              _HeroCard(account: account, balance: balance),
              // ── Detail rows ───────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Type',
                      value: account.type
                          .split(' ')
                          .map((w) => w[0].toUpperCase() + w.substring(1))
                          .join(' '),
                    ),
                    _DetailRow(label: 'Currency', value: account.currency),
                    _DetailRow(
                      label: 'Opening balance',
                      value: MoneyFormatter.format(
                        account.openingBalanceMinor,
                        code: account.currency,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Recent transactions ───────────────────────────────────
              if (recent.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent transactions',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.onSurface,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'View All',
                          style: TextStyle(color: colors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                ...recent.map(
                  (t) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TransactionCard(transaction: t),
                  ),
                ),
              ],
              SizedBox(height: AppLayout.safeScrollBottom(context)),
            ],
          );
        },
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.account, required this.balance});

  final Account account;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final acctColor = Color(account.color);
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current balance',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              MoneyFormatter.format(balance),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: acctColor.withValues(alpha: 0.14),
                  child: Icon(
                    IconData(account.icon, fontFamily: 'MaterialIcons'),
                    color: acctColor,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: acctColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    account.type,
                    style: TextStyle(
                      color: acctColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    account.currency,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Sparkline placeholder
            Container(
              height: 56,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: CustomPaint(
                painter: _SparklinePainter(color: acctColor),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Balance · last 30 days',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [0.6, 0.4, 0.5, 0.3, 0.45, 0.35, 0.5, 0.4, 0.55, 0.45];
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i / (points.length - 1) * size.width;
      final y = size.height - points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => false;
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent tile ───────────────────────────────────────────────────────────────
