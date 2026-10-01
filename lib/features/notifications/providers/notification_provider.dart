import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/app_notification.dart';

class NotificationController
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationController() : super(const AsyncLoading()) {
    refresh();
  }
  Future<void> refresh() async =>
      state = AsyncData(await AppDatabase.instance.notifications());
  Future<void> markRead(int id) async {
    await AppDatabase.instance.markNotificationRead(id);
    await refresh();
  }

  Future<void> markAllRead() async {
    await AppDatabase.instance.markAllNotificationsRead();
    await refresh();
  }

  Future<void> delete(int id) async {
    await AppDatabase.instance.deleteNotification(id);
    await refresh();
  }

  Future<void> clear() async {
    await AppDatabase.instance.clearNotifications();
    await refresh();
  }
}

final notificationListProvider =
    StateNotifierProvider<
      NotificationController,
      AsyncValue<List<AppNotification>>
    >((_) => NotificationController());

final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref
      .watch(notificationListProvider)
      .maybeWhen(
        data: (items) => items.where((item) => !item.isRead).length,
        orElse: () => 0,
      ),
);
