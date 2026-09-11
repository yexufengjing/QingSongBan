import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/database/database_provider.dart';
import '../data/personnel_repository.dart';

final personnelRepositoryProvider = Provider<PersonnelRepository>((ref) {
  return PersonnelRepository(ref.watch(appDatabaseProvider));
});

final personnelSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final personnelStatusFilterProvider =
    StateProvider.autoDispose<EmployeeStatus?>((ref) => null);

final personnelAttendanceGroupFilterProvider = StateProvider.autoDispose<int?>(
  (ref) => null,
);

final personnelEmploymentTypeFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final personnelShowDeletedProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

final personnelListProvider = StreamProvider.autoDispose<List<Employee>>((ref) {
  return ref
      .watch(personnelRepositoryProvider)
      .watchEmployees(
        search: ref.watch(personnelSearchQueryProvider),
        status: ref.watch(personnelStatusFilterProvider),
        attendanceGroupId: ref.watch(personnelAttendanceGroupFilterProvider),
        employmentType: ref.watch(personnelEmploymentTypeFilterProvider),
        includeDeleted: ref.watch(personnelShowDeletedProvider),
      );
});

final allPersonnelProvider = StreamProvider.autoDispose<List<Employee>>((ref) {
  return ref.watch(personnelRepositoryProvider).watchEmployees();
});

final attendanceGroupsProvider =
    StreamProvider.autoDispose<List<AttendanceGroup>>((ref) {
      return ref.watch(personnelRepositoryProvider).watchAttendanceGroups();
    });

final employeeProvider = FutureProvider.autoDispose.family<Employee?, int>((
  ref,
  id,
) {
  return ref.watch(personnelRepositoryProvider).findById(id);
});
