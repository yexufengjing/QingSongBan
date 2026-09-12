import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../data/attendance_group_repository.dart';
import '../data/daily_attendance_repository.dart';
import '../domain/daily_attendance_options.dart';

final dailyAttendanceRepositoryProvider = Provider<DailyAttendanceRepository>((
  ref,
) {
  return DailyAttendanceRepository(ref.watch(appDatabaseProvider));
});

final dailyAttendanceDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  return AppDateUtils.dateOnly(DateTime.now());
});

final dailyAttendanceGroupIdProvider = StateProvider.autoDispose<int?>(
  (ref) => null,
);

final dailyAttendanceGroupsProvider =
    StreamProvider.autoDispose<List<AttendanceGroup>>((ref) {
      return AttendanceGroupRepository(ref.watch(appDatabaseProvider))
          .watchEnabledGroups();
    });

final dailyAttendanceEntriesProvider =
    StreamProvider.autoDispose<List<DailyAttendanceEntryView>>((ref) {
      final date = ref.watch(dailyAttendanceDateProvider);
      final groupId = ref.watch(dailyAttendanceGroupIdProvider);
      if (groupId == null) {
        return Stream.value(const <DailyAttendanceEntryView>[]);
      }
      return ref
          .watch(dailyAttendanceRepositoryProvider)
          .watchEntries(attendanceDate: date, groupId: groupId);
    });
