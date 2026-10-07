import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'features/sms_detection/background/sms_background_entrypoint.dart';
import 'core/theme/theme_provider.dart';

export 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialThemeMode = await bootstrap();
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          (_) => ThemeController(initialMode: initialThemeMode),
        ),
      ],
      child: const FlowlyApp(),
    ),
  );
}

@pragma('vm:entry-point')
void smsBackgroundMain() async {
  await runSmsBackgroundWorker();
}
