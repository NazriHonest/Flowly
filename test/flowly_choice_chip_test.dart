import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/core/theme/app_theme.dart';
import 'package:flowly/core/widgets/app_widgets.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('currency chip resolves selected and unselected $mode colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: Scaffold(
            body: Row(
              children: [
                FlowlyChoiceChip(
                  label: const Text('KES'),
                  selected: true,
                  onSelected: (_) {},
                ),
                FlowlyChoiceChip(
                  label: const Text('USD'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      final scheme = Theme.of(context).colorScheme;
      final chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .toList();

      expect(chips[0].selectedColor, scheme.primaryContainer);
      expect(chips[0].checkmarkColor, scheme.onPrimaryContainer);
      expect(chips[1].backgroundColor, scheme.surfaceContainerHighest);
      expect(chips[0].selectedColor, isNot(chips[1].backgroundColor));
    });
  }
}
