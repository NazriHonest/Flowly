import '../core/database/app_database.dart';
import '../core/theme/theme_provider.dart';
import '../features/recurring/domain/services/recurring_generator.dart';
import '../core/formatters/money_formatter.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/notifications/data/local_notification_service.dart';

/// Initializes local services before the first frame.  Database migrations are
/// performed by [AppDatabase] and are idempotent.
Future<ThemeMode> bootstrap() async {
  final preferences = await SharedPreferences.getInstance();
  final themeMode = ThemeController.modeFromStoredValue(
    preferences.getString('theme'),
  );
  MoneyFormatter.configure(preferences.getString('defaultCurrency') ?? 'KES');
  await LocalNotificationService.instance.initialize();
  await AppDatabase.instance.db;
  await AppDatabase.instance.recordCurrentBudgetLimits();
  await RecurringGenerator(AppDatabase.instance).generateDue(DateTime.now());
  return themeMode;
}
