import '../../reminders/domain/reminder_options.dart';
import '../../../core/database/app_database.dart';

/// Data shown by the calendar for one visible month, including its leading and
/// trailing days. Todos and daily entries come from the same database snapshot.
class CalendarSnapshot {
  const CalendarSnapshot({required this.todos, required this.entries});

  final List<ReminderItem> todos;
  final List<DailyEntry> entries;
}
