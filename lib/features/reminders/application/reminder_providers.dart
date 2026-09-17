import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/reminder_repository.dart';
import '../domain/reminder_options.dart';
import 'notification_service.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(appDatabaseProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final remindersProvider = StreamProvider.autoDispose<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchReminders();
});

final reminderItemsProvider = StreamProvider.autoDispose<List<ReminderItem>>((
  ref,
) {
  return ref.watch(reminderRepositoryProvider).watchReminderItems();
});

final reminderItemProvider = FutureProvider.autoDispose
    .family<ReminderItem?, int>(
      (ref, id) => ref.watch(reminderRepositoryProvider).findItemById(id),
    );
