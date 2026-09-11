import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  late AppDatabase database;
  late PersonnelRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = PersonnelRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves a generated employee number and updates the record', () async {
    final employee = await repository.save(
      draft: EmployeeDraft(
        employeeNo: '',
        name: '张三',
        hireDate: DateTime(2026, 9, 1),
        status: EmployeeStatus.active,
        employmentType: '临时工',
      ),
    );

    expect(employee.employeeNo, 'EMP-0001');
    expect(employee.name, '张三');

    final updated = await repository.save(
      id: employee.id,
      draft: EmployeeDraft(
        employeeNo: employee.employeeNo,
        name: '李四',
        hireDate: employee.hireDate,
        status: EmployeeStatus.paused,
        employmentType: '正式工',
      ),
    );

    expect(updated.id, employee.id);
    expect(updated.name, '李四');
    expect(updated.status, EmployeeStatus.paused);
    expect(updated.employmentType, '正式工');
  });

  test('filters personnel by search, status, and employment type', () async {
    await repository.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-1001',
        name: '张三',
        hireDate: DateTime(2026, 9, 1),
        status: EmployeeStatus.active,
        position: '操作工',
        employmentType: '临时工',
      ),
    );
    await repository.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-1002',
        name: '李四',
        hireDate: DateTime(2026, 9, 1),
        status: EmployeeStatus.paused,
        position: '司机',
        employmentType: '正式工',
      ),
    );

    final result = await repository
        .watchEmployees(
          search: '操作工',
          status: EmployeeStatus.active,
          employmentType: '临时工',
        )
        .first;

    expect(result, hasLength(1));
    expect(result.single.name, '张三');
  });

  test('soft deletes and restores a record through the repository', () async {
    final employee = await repository.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-2001',
        name: '王五',
        hireDate: DateTime(2026, 9, 1),
        status: EmployeeStatus.active,
      ),
    );

    expect(await repository.softDelete(employee.id), 1);
    expect(await repository.watchEmployees().first, isEmpty);
    expect(
      await repository.watchEmployees(includeDeleted: true).first,
      hasLength(1),
    );

    expect(await repository.restore(employee.id), 1);
    expect(await repository.watchEmployees().first, hasLength(1));
  });
}
