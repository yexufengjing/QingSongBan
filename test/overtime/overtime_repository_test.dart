import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/overtime/data/overtime_repository.dart';
import 'package:qingsongban/features/overtime/domain/overtime_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  late AppDatabase database;
  late OvertimeRepository overtimeRepository;
  late PersonnelRepository personnelRepository;

  setUp(() {
    database = AppDatabase.forTesting();
    overtimeRepository = OvertimeRepository(database);
    personnelRepository = PersonnelRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Employee> createEmployee(String employeeNo, String name) {
    return personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: employeeNo,
        name: name,
        hireDate: DateTime(2026, 1, 1),
        status: EmployeeStatus.active,
      ),
    );
  }

  OvertimeRecordDraft draft({
    required int employeeId,
    required DateTime start,
    required DateTime end,
  }) {
    return OvertimeRecordDraft(
      employeeId: employeeId,
      overtimeDate: DateTime(start.year, start.month, start.day),
      startTime: start,
      endTime: end,
      overtimeType: 'weekday',
      workContent: '设备检修',
    );
  }

  test('stores exact duration and formats hours and minutes', () async {
    final employee = await createEmployee('EMP-O001', '张三');
    final record = await overtimeRepository.save(
      draft: draft(
        employeeId: employee.id,
        start: DateTime(2026, 9, 12, 18),
        end: DateTime(2026, 9, 12, 20, 30),
      ),
    );

    expect(record.durationMinutes, 150);
    expect(OvertimeOptions.formatDuration(record.durationMinutes), '2小时30分钟');
    expect(
      (await overtimeRepository.watchOvertime(month: DateTime(2026, 9)).first)
          .single
          .employee
          .name,
      '张三',
    );
  });

  test(
    'allows multiple non-overlapping segments and sums them in the list',
    () async {
      final employee = await createEmployee('EMP-O101', '李四');
      await overtimeRepository.save(
        draft: draft(
          employeeId: employee.id,
          start: DateTime(2026, 9, 12, 18),
          end: DateTime(2026, 9, 12, 20, 30),
        ),
      );
      await overtimeRepository.save(
        draft: draft(
          employeeId: employee.id,
          start: DateTime(2026, 9, 12, 21),
          end: DateTime(2026, 9, 12, 21, 45),
        ),
      );

      final records = await overtimeRepository
          .watchOvertime(month: DateTime(2026, 9))
          .first;
      expect(records, hasLength(2));
      expect(
        records.fold<int>(
          0,
          (total, item) => total + item.overtime.durationMinutes,
        ),
        195,
      );
      expect(OvertimeOptions.formatDuration(45), '45分钟');
      expect(OvertimeOptions.formatDuration(60), '1小时');
    },
  );

  test('rejects overlapping segments for the same employee and day', () async {
    final employee = await createEmployee('EMP-O201', '王五');
    await overtimeRepository.save(
      draft: draft(
        employeeId: employee.id,
        start: DateTime(2026, 9, 12, 18),
        end: DateTime(2026, 9, 12, 20),
      ),
    );

    await expectLater(
      overtimeRepository.save(
        draft: draft(
          employeeId: employee.id,
          start: DateTime(2026, 9, 12, 19, 59),
          end: DateTime(2026, 9, 12, 21),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      await overtimeRepository.watchOvertime(month: DateTime(2026, 9)).first,
      hasLength(1),
    );
  });

  test('editing can move a segment after overlap validation', () async {
    final employee = await createEmployee('EMP-O301', '赵六');
    final record = await overtimeRepository.save(
      draft: draft(
        employeeId: employee.id,
        start: DateTime(2026, 9, 12, 18),
        end: DateTime(2026, 9, 12, 20),
      ),
    );
    final updated = await overtimeRepository.save(
      id: record.id,
      draft: draft(
        employeeId: employee.id,
        start: DateTime(2026, 9, 13, 18),
        end: DateTime(2026, 9, 13, 19),
      ),
    );
    expect(updated.id, record.id);
    expect(updated.durationMinutes, 60);
    expect(
      await overtimeRepository.watchOvertime(month: DateTime(2026, 9)).first,
      hasLength(1),
    );
  });
}
