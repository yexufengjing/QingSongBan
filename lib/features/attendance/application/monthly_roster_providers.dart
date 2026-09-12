import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../data/attendance_group_repository.dart';
import '../data/monthly_roster_repository.dart';
import '../domain/monthly_roster_options.dart';

final monthlyRosterRepositoryProvider = Provider<MonthlyRosterRepository>((
  ref,
) {
  return MonthlyRosterRepository(ref.watch(appDatabaseProvider));
});

final monthlyRosterMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthlyRosterGroupIdProvider = StateProvider.autoDispose<int?>(
  (ref) => null,
);

final monthlyRosterShowRemovedProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

final monthlyRosterGroupsProvider =
    StreamProvider.autoDispose<List<AttendanceGroup>>((ref) {
      return AttendanceGroupRepository(ref.watch(appDatabaseProvider))
          .watchAllGroups();
    });

final monthlyRosterEntriesProvider =
    StreamProvider.autoDispose<List<MonthlyRosterEntryView>>((ref) {
      final month = ref.watch(monthlyRosterMonthProvider);
      final groupId = ref.watch(monthlyRosterGroupIdProvider);
      if (groupId == null) {
        return Stream.value(const <MonthlyRosterEntryView>[]);
      }
      return ref
          .watch(monthlyRosterRepositoryProvider)
          .watchRoster(
            yearMonth: AppDateUtils.yearMonth(month),
            groupId: groupId,
            includeRemoved: ref.watch(monthlyRosterShowRemovedProvider),
          );
    });

final monthlyRosterCountsProvider =
    StreamProvider.autoDispose<MonthlyRosterCounts>((ref) {
      final month = ref.watch(monthlyRosterMonthProvider);
      final groupId = ref.watch(monthlyRosterGroupIdProvider);
      if (groupId == null) {
        return Stream.value(const MonthlyRosterCounts());
      }
      return ref
          .watch(monthlyRosterRepositoryProvider)
          .watchCounts(
            yearMonth: AppDateUtils.yearMonth(month),
            groupId: groupId,
          );
    });

final monthlyRosterCandidatesProvider =
    StreamProvider.autoDispose<List<Employee>>((ref) {
      final month = ref.watch(monthlyRosterMonthProvider);
      return ref
          .watch(monthlyRosterRepositoryProvider)
          .watchEligibleEmployees(yearMonth: AppDateUtils.yearMonth(month));
    });
