import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';

const accountBalanceMask = '••••••';

class BalanceVisibilityController extends StateNotifier<bool> {
  BalanceVisibilityController() : super(false);

  void toggle() => state = !state;

  void hide() => state = false;
}

final balanceVisibilityProvider =
    StateNotifierProvider<BalanceVisibilityController, bool>(
      (_) => BalanceVisibilityController(),
    );

class AccountBalanceText extends ConsumerWidget {
  const AccountBalanceText({
    super.key,
    required this.amountMinor,
    this.currencyCode,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final int amountMinor;
  final String? currencyCode;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(balanceVisibilityProvider);
    return Text(
      visible
          ? MoneyFormatter.format(amountMinor, code: currencyCode)
          : accountBalanceMask,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: style,
    );
  }
}

class BalanceVisibilityButton extends ConsumerWidget {
  const BalanceVisibilityButton({super.key, this.foregroundColor});

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(balanceVisibilityProvider);
    final label = visible ? 'Hide balances' : 'Show balances';
    return IconButton(
      tooltip: label,
      color: foregroundColor,
      onPressed: () => ref.read(balanceVisibilityProvider.notifier).toggle(),
      icon: Icon(
        visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        semanticLabel: label,
      ),
    );
  }
}
