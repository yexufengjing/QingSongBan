import 'package:rrule/rrule.dart';

import '../../../core/database/app_database.dart';

/// Converts the reminder's wall-clock time to the UTC-shaped values expected
/// by `rrule`, then converts occurrences back without applying a second zone
/// offset. The database stores a local wall time; NotificationService applies
/// the device timezone only at the final scheduling boundary.
class RecurrenceService {
  const RecurrenceService();

  List<DateTime> generateOccurrences(
    Reminder reminder, {
    DateTime? from,
    Duration window = const Duration(days: 366),
    int limit = 30,
  }) {
    final due = reminder.dueDate;
    if (due == null || limit <= 0) return const [];
    final ruleText = reminder.repeatRule;
    if (ruleText == null || ruleText.trim().isEmpty) return [due];

    final rule = RecurrenceRule.fromString(
      ruleText.startsWith('RRULE:') ? ruleText : 'RRULE:$ruleText',
    );
    final start = _asRruleDate(due);
    final fromDate = from ?? DateTime.now();
    final after = _asRruleDate(fromDate.isBefore(due) ? due : fromDate);
    final before = _asRruleDate(fromDate.add(window));
    return rule
        .getInstances(
          start: start,
          after: after,
          includeAfter: true,
          before: before,
          includeBefore: true,
        )
        .take(limit)
        .map(_fromRruleDate)
        .toList(growable: false);
  }

  DateTime? nextOccurrence(Reminder reminder, {DateTime? from}) {
    final values = generateOccurrences(reminder, from: from, limit: 1);
    return values.isEmpty ? null : values.first;
  }

  DateTime _asRruleDate(DateTime value) => DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );

  DateTime _fromRruleDate(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}
