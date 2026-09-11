import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  late AppDatabase database;
  late AttendanceGroupRepository groupRepository;
  late PersonnelRepository personnelRepository;

  setUp(() {
    database = AppDatabase.forTesting();
    groupRepository = AttendanceGroupRepository(database);
    personnelRepository = PersonnelRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates, edits, and rejects duplicate attendance groups', () async {
    final group = await groupRepository.save(
      draft: const AttendanceGroupDraft(
        name: '特钢临时工组',
        sortOrder: 2,
        remark: '特钢区域',
      ),
    );

    expect(group.name, '特钢临时工组');
    expect(group.groupType, 'manual');
    expect(group.sortOrder, 2);

    final updated = await groupRepository.save(
      id: group.id,
      draft: const AttendanceGroupDraft(
        name: '特钢临时工组（白班）',
        sortOrder: 1,
        isEnabled: false,
      ),
    );
    expect(updated.name, '特钢临时工组（白班）');
    expect(updated.isEnabled, isFalse);
    expect(updated.sortOrder, 1);

    await expectLater(
      groupRepository.save(
        draft: const AttendanceGroupDraft(name: ' 特钢临时工组（白班） '),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'enables and disables groups while active queries exclude disabled ones',
    () async {
      final group = await groupRepository.save(
        draft: const AttendanceGroupDraft(name: '司机组'),
      );

      expect(await groupRepository.watchGroupSummaries().first, hasLength(1));
      await groupRepository.setEnabled(group.id, false);
      expect(
        await groupRepository.watchGroupSummaries(includeDisabled: false).first,
        isEmpty,
      );

      await groupRepository.setEnabled(group.id, true);
      final summaries = await groupRepository.watchGroupSummaries().first;
      expect(summaries.single.group.isEnabled, isTrue);
    },
  );

  test(
    'moving a person keeps one default group and one active membership',
    () async {
      final first = await groupRepository.save(
        draft: const AttendanceGroupDraft(name: '绿化组'),
      );
      final second = await groupRepository.save(
        draft: const AttendanceGroupDraft(name: '环卫组'),
      );
      final employee = await personnelRepository.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-3001',
          name: '赵六',
          hireDate: DateTime(2026, 9, 1),
          status: EmployeeStatus.active,
        ),
      );

      await groupRepository.assignEmployeeToGroup(
        employeeId: employee.id,
        groupId: first.id,
      );
      await groupRepository.assignEmployeeToGroup(
        employeeId: employee.id,
        groupId: second.id,
      );

      final savedEmployee = await personnelRepository.findById(employee.id);
      expect(savedEmployee?.defaultAttendanceGroupId, second.id);
      expect(await groupRepository.watchMembers(first.id).first, isEmpty);
      expect(await groupRepository.watchMembers(second.id).first, hasLength(1));

      final memberships = await (database.select(
        database.attendanceGroupMembers,
      )..where((table) => table.employeeId.equals(employee.id))).get();
      expect(memberships, hasLength(2));
      expect(memberships.where((item) => !item.isDeleted), hasLength(1));
      expect(
        memberships.singleWhere((item) => !item.isDeleted).isDefault,
        isTrue,
      );

      await groupRepository.clearEmployeeFromGroup(
        employeeId: employee.id,
        groupId: second.id,
      );
      expect(
        (await personnelRepository.findById(employee.id))
            ?.defaultAttendanceGroupId,
        isNull,
      );
      expect(await groupRepository.watchMembers(second.id).first, isEmpty);
    },
  );

  test(
    'disabling a group preserves existing defaults but blocks new assignment',
    () async {
      final group = await groupRepository.save(
        draft: const AttendanceGroupDraft(name: '重科临时工组'),
      );
      final firstEmployee = await personnelRepository.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-4001',
          name: '钱七',
          hireDate: DateTime(2026, 9, 1),
          status: EmployeeStatus.active,
          defaultAttendanceGroupId: group.id,
        ),
      );
      await groupRepository.setEnabled(group.id, false);

      expect(
        (await personnelRepository.findById(firstEmployee.id))
            ?.defaultAttendanceGroupId,
        group.id,
      );

      final secondEmployee = await personnelRepository.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-4002',
          name: '孙八',
          hireDate: DateTime(2026, 9, 1),
          status: EmployeeStatus.active,
        ),
      );
      await expectLater(
        groupRepository.assignEmployeeToGroup(
          employeeId: secondEmployee.id,
          groupId: group.id,
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
}
