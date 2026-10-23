import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_models.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(appDatabaseProvider));
});

/// [month] is normalized to the first day of its month by callers.
final calendarMonthProvider = StreamProvider.autoDispose
    .family<CalendarSnapshot, DateTime>((ref, month) {
      return ref.watch(calendarRepositoryProvider).watchMonth(month);
    });
