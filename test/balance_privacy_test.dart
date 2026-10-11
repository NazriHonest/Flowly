import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowly/features/accounts/presentation/balance_privacy.dart';

void main() {
  testWidgets('account balances are absent from the rendered tree by default', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AccountBalanceText(amountMinor: 12345, currencyCode: 'USD'),
                BalanceVisibilityButton(),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text(r'$123.45'), findsNothing);
    expect(find.text(accountBalanceMask), findsOneWidget);
    expect(find.bySemanticsLabel('Show balances'), findsOneWidget);

    await tester.tap(find.byTooltip('Show balances'));
    await tester.pump();

    expect(find.text(r'$123.45'), findsOneWidget);
    expect(find.text(accountBalanceMask), findsNothing);
    expect(find.bySemanticsLabel('Hide balances'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide balances'));
    await tester.pump();

    expect(find.text(r'$123.45'), findsNothing);
    expect(find.text(accountBalanceMask), findsOneWidget);
    semantics.dispose();
  });

  test('visibility is session-only and can be forcibly hidden', () {
    final first = BalanceVisibilityController();
    first.toggle();
    expect(first.state, isTrue);
    first.hide();
    expect(first.state, isFalse);

    final coldStart = BalanceVisibilityController();
    expect(coldStart.state, isFalse);
  });
}
