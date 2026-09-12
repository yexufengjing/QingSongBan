import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../data/attendance_group_repository.dart';
import '../data/monthly_attendance_table_repository.dart';
import '../domain/monthly_attendance_table_options.dart';

final monthlyAttendanceTableRepositoryProvider =
    Provider<MonthlyAttendanceTableRepository>((ref) {
      return MonthlyAttendanceTableRepository(ref.watch(appDatabaseProvider));
    });

final monthlyAttendanceTableMonthProvider = StateProvider.autoDispose<DateTime>(
  (ref) {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  },
);

final monthlyAttendanceTableGroupIdProvider = StateProvider.autoDispose<int?>(
  (ref) => null,
);

final monthlyAttendanceTableGroupsProvider =
    StreamProvider.autoDispose<List<AttendanceGroup>>((ref) {
      return AttendanceGroupRepository(ref.watch(appDatabaseProvider))
          .watchAllGroups();
    });

final monthlyAttendanceTableProvider =
    StreamProvider.autoDispose<MonthlyAttendanceTableView>((ref) {
      final month = ref.watch(monthlyAttendanceTableMonthProvider);
      final groupId = ref.watch(monthlyAttendanceTableGroupIdProvider);
      if (groupId == null) {
        return Stream.value(
          MonthlyAttendanceTableView.empty(
            yearMonth: AppDateUtils.yearMonth(month),
          ),
        );
      }
      return ref
          .watch(monthlyAttendanceTableRepositoryProvider)
          .watchTable(
            yearMonth: AppDateUtils.yearMonth(month),
            groupId: groupId,
          );
    });
