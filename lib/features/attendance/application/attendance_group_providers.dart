import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/attendance_group_repository.dart';
import '../domain/attendance_group_options.dart';

final attendanceGroupRepositoryProvider = Provider<AttendanceGroupRepository>((
  ref,
) {
  return AttendanceGroupRepository(ref.watch(appDatabaseProvider));
});

final attendanceGroupSummariesProvider =
    StreamProvider.autoDispose<List<AttendanceGroupSummary>>((ref) {
      return ref.watch(attendanceGroupRepositoryProvider).watchGroupSummaries();
    });

final attendanceGroupProvider = FutureProvider.autoDispose
    .family<AttendanceGroup?, int>((ref, id) {
      return ref.watch(attendanceGroupRepositoryProvider).findById(id);
    });

final attendanceGroupMembersProvider = StreamProvider.autoDispose
    .family<List<AttendanceGroupMemberView>, int>((ref, groupId) {
      return ref.watch(attendanceGroupRepositoryProvider).watchMembers(groupId);
    });

final attendanceGroupAssignableEmployeesProvider =
    StreamProvider.autoDispose<List<Employee>>((ref) {
      return ref
          .watch(attendanceGroupRepositoryProvider)
          .watchAssignableEmployees();
    });
