import 'package:flowly/core/theme/app_colors.dart';
import 'package:flowly/core/theme/app_theme.dart';
import 'package:flowly/core/theme/theme_provider.dart';
import 'package:flowly/core/widgets/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('semantic foregrounds remain readable in both themes', () {
    final light = AppTheme.light.extension<FlowlySemanticColors>()!;
    final dark = AppTheme.dark.extension<FlowlySemanticColors>()!;

    for (final color in [
      light.incomeForeground,
      light.expenseForeground,
      light.transferForeground,
      light.warningForeground,
      light.infoForeground,
    ]) {
      expect(
        _contrastRatio(color, AppColors.lightSurface),
        greaterThanOrEqualTo(4.5),
      );
    }

    for (final color in [
      dark.incomeForeground,
      dark.expenseForeground,
      dark.transferForeground,
      dark.warningForeground,
      dark.infoForeground,
    ]) {
      expect(
        _contrastRatio(color, AppColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('primary action pair meets normal-text contrast', () {
    expect(
      _contrastRatio(AppColors.onPrimary, AppColors.primaryAction),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('stored theme values restore safely', () {
    expect(ThemeController.modeFromStoredValue('light'), ThemeMode.light);
    expect(ThemeController.modeFromStoredValue('dark'), ThemeMode.dark);
    expect(ThemeController.modeFromStoredValue('system'), ThemeMode.system);
    expect(ThemeController.modeFromStoredValue('invalid'), ThemeMode.system);
    expect(ThemeController.modeFromStoredValue(null), ThemeMode.system);
  });

  test('identity foreground helper selects a contrasting foreground', () {
    expect(
      AppColors.foregroundOn(const Color(0xFFF59E0B)),
      AppColors.lightTextPrimary,
    );
    expect(AppColors.foregroundOn(const Color(0xFF034E3A)), Colors.white);
  });

  testWidgets('shared error state uses theme error semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppErrorState(
            title: 'Error',
            message: 'Try again',
            onRetry: () {},
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(AppErrorState));
    final colors = Theme.of(context).colorScheme;
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
    expect(icon.color, colors.onErrorContainer);
  });
}
