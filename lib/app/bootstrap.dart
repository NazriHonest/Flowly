import '../core/database/app_database.dart';
import '../features/recurring/domain/services/recurring_generator.dart';
import '../core/formatters/money_formatter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/notifications/data/local_notification_service.dart';

/// Initializes local services before the first frame.  Database migrations are
/// performed by [AppDatabase] and are idempotent.
Future<void> bootstrap() async {
  final preferences = await SharedPreferences.getInstance();
  MoneyFormatter.configure(preferences.getString('defaultCurrency') ?? 'KES');
  await LocalNotificationService.instance.initialize();
  await AppDatabase.instance.db;
  await RecurringGenerator(AppDatabase.instance).generateDue(DateTime.now());
}
