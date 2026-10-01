import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/goal.dart';
import '../../notifications/data/local_notification_service.dart';

class GoalController extends StateNotifier<AsyncValue<List<Goal>>> {
  GoalController() : super(const AsyncLoading()) {
    refresh();
  }
  Future<void> refresh() async =>
      state = AsyncData(await AppDatabase.instance.goals());
  Future<void> save(Goal goal) async {
    await AppDatabase.instance.saveGoal(goal);
    await refresh();
  }

  Future<void> contribute(int id, int amount) async {
    final before = state.valueOrNull
        ?.where((goal) => goal.id == id)
        .firstOrNull;
    await AppDatabase.instance.contributeToGoal(id, amount);
    await refresh();
    final after = state.valueOrNull?.where((goal) => goal.id == id).firstOrNull;
    if (before != null &&
        after != null &&
        before.currentMinor < before.targetMinor &&
        after.currentMinor >= after.targetMinor) {
      await AppDatabase.instance.createNotification(
        'Goal reached',
        '${after.name} has reached its target.',
      );
      await LocalNotificationService.instance.show(
        event: 'goals',
        id: id,
        title: 'Goal reached',
        body: '${after.name} has reached its target.',
      );
    }
  }

  Future<void> delete(int id) async {
    await AppDatabase.instance.deleteGoal(id);
    await refresh();
  }
}

final goalListProvider =
    StateNotifierProvider<GoalController, AsyncValue<List<Goal>>>(
      (_) => GoalController(),
    );
