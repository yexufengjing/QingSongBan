import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/reminder_repository.dart';
import '../domain/reminder_options.dart';
import 'reminder_scheduler.dart';
import 'notification_service.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(appDatabaseProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler(
    ref.watch(reminderRepositoryProvider),
    ref.watch(notificationServiceProvider),
  );
});

final remindersProvider = StreamProvider.autoDispose<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchReminders();
});

final reminderItemsProvider = FutureProvider.autoDispose
    .family<List<ReminderListItem>, ({String search, String view})>((
      ref,
      filter,
    ) {
      return ref
          .watch(reminderRepositoryProvider)
          .listReminderItems(search: filter.search, view: filter.view);
    });

final employeeReminderItemsProvider = FutureProvider.autoDispose
    .family<List<ReminderListItem>, int>((ref, id) {
      return ref
          .watch(reminderRepositoryProvider)
          .listItemsForEntity('employee', id);
    });
