import '../../../../core/database/app_database.dart';
import 'recurrence_scheduler.dart';
import '../../../notifications/data/local_notification_service.dart';

class RecurringGenerator {
  const RecurringGenerator(
    this._database, {
    this.scheduler = const RecurrenceScheduler(),
  });
  final AppDatabase _database;
  final RecurrenceScheduler scheduler;
  Future<int> generateDue(DateTime now) async {
    var generated = 0;
    for (final item in await _database.recurringTransactions()) {
      if (!scheduler.isDue(item, now) ||
          item.endDate?.isBefore(item.nextOccurrence) == true) {
        continue;
      }
      if (await _database.generateRecurringOccurrence(
        item,
        item.nextOccurrence,
        scheduler.nextAfter(item),
      )) {
        generated++;
        await _database.createNotification(
          'Recurring transaction generated',
          '${item.title} was added to your transactions.',
        );
        await LocalNotificationService.instance.show(
          event: 'recurring',
          id: item.id! ^ item.nextOccurrence.millisecondsSinceEpoch,
          title: 'Recurring transaction generated',
          body: '${item.title} was added to your transactions.',
        );
      }
    }
    return generated;
  }
}
