import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flowly/features/sms_detection/providers/automatic_detection_provider.dart';

void main() {
  testWidgets('successful Enable advances to the account step', (tester) async {
    final controller = _controller(requestResult: true);
    await _pumpOnboarding(tester, controller);
    await _reachDetectionStep(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Enable automatic detection'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create your first account'), findsOneWidget);
    expect(controller.state, isTrue);
  });

  testWidgets('permission denial does not advance onboarding', (tester) async {
    final controller = _controller(requestResult: false);
    await _pumpOnboarding(tester, controller);
    await _reachDetectionStep(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Enable automatic detection'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permission not granted'), findsOneWidget);
    expect(find.text('Create your first account'), findsNothing);
    expect(controller.state, isFalse);
  });

  testWidgets('Not Now advances once with detection disabled', (tester) async {
    final controller = _controller(requestResult: true);
    await _pumpOnboarding(tester, controller);
    await _reachDetectionStep(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Not Now'));
    await tester.pumpAndSettle();

    expect(find.text('Create your first account'), findsOneWidget);
    expect(controller.state, isFalse);
  });

  testWidgets('education Not now also advances with detection disabled', (
    tester,
  ) async {
    final controller = _controller(requestResult: true);
    await _pumpOnboarding(tester, controller);
    await _reachDetectionStep(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Create your first account'), findsOneWidget);
    expect(controller.state, isFalse);
  });
}

AutomaticDetectionController _controller({required bool requestResult}) =>
    AutomaticDetectionController(
      store: _MemoryStore(),
      platform: _FakePlatform(requestResult),
      restoreOnCreate: false,
    );

Future<void> _pumpOnboarding(
  WidgetTester tester,
  AutomaticDetectionController controller,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [automaticDetectionProvider.overrideWith((ref) => controller)],
      child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
    ),
  );
}

Future<void> _reachDetectionStep(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();
  }
  expect(find.text('Automatic transaction detection'), findsOneWidget);
}

class _MemoryStore implements AutomaticDetectionStore {
  bool enabled = false;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<bool> writeEnabled(bool value) async {
    enabled = value;
    return true;
  }
}

class _FakePlatform implements AutomaticDetectionPlatform {
  _FakePlatform(this.requestResult);
  final bool requestResult;
  bool permission = false;

  @override
  Future<bool> permissionGranted() async => permission;

  @override
  Future<bool> requestPermission() async {
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<void> synchronizeReceiver(bool enabled) async {}
}
