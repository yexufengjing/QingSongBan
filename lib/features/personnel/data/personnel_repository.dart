import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../attendance/data/attendance_group_repository.dart';
import '../domain/personnel_options.dart';

class PersonnelRepository {
  const PersonnelRepository(this._database);

  final AppDatabase _database;

  Stream<List<Employee>> watchEmployees({
    String search = '',
    EmployeeStatus? status,
    int? attendanceGroupId,
    String? employmentType,
    bool includeDeleted = false,
  }) {
    final query = _database.select(_database.employees)
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);

    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    if (status != null) {
      query.where((table) => table.status.equalsValue(status));
    }
    if (attendanceGroupId != null) {
      query.where(
        (table) => table.defaultAttendanceGroupId.equals(attendanceGroupId),
      );
    }
    if (employmentType != null && employmentType.isNotEmpty) {
      query.where((table) => table.employmentType.equals(employmentType));
    }
    final normalizedSearch = search.trim();
    if (normalizedSearch.isNotEmpty) {
      final pattern = '%$normalizedSearch%';
      query.where(
        (table) =>
            table.name.like(pattern) |
            table.employeeNo.like(pattern) |
            table.position.like(pattern) |
            table.team.like(pattern) |
            table.workArea.like(pattern),
      );
    }
    return query.watch();
  }

  Stream<List<AttendanceGroup>> watchAttendanceGroups() {
    final query = _database.select(_database.attendanceGroups)
      ..where(
        (table) => table.isDeleted.equals(false) & table.isEnabled.equals(true),
      )
      ..orderBy([
        (table) => OrderingTerm(expression: table.sortOrder),
        (table) => OrderingTerm(expression: table.name),
      ]);
    return query.watch();
  }

  Future<Employee?> findById(int id) {
    return (_database.select(
      _database.employees,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<Employee> save({int? id, required EmployeeDraft draft}) async {
    final employeeNo = draft.employeeNo.trim().isEmpty
        ? await _nextEmployeeNo()
        : draft.employeeNo.trim();
    final now = DateTime.now();
    final previousEmployee = id == null ? null : await findById(id);
    final attendanceGroupRepository = AttendanceGroupRepository(_database);
    final values = EmployeesCompanion(
      employeeNo: Value(employeeNo),
      name: Value(draft.name.trim()),
      gender: Value(draft.gender),
      idCardNumber: Value(_nullableText(draft.idCardNumber)),
      birthDate: Value(draft.birthDate),
      phone: Value(_nullableText(draft.phone)),
      address: Value(_nullableText(draft.address)),
      hireDate: Value(draft.hireDate),
      status: Value(draft.status),
      position: Value(_nullableText(draft.position)),
      team: Value(_nullableText(draft.team)),
      workArea: Value(_nullableText(draft.workArea)),
      manager: Value(_nullableText(draft.manager)),
      employmentType: Value(_nullableText(draft.employmentType)),
      defaultAttendanceGroupId: Value(draft.defaultAttendanceGroupId),
      remark: Value(_nullableText(draft.remark)),
      updatedAt: Value(now),
    );

    late final int employeeId;
    await _database.transaction(() async {
      if (id == null) {
        employeeId = await _database
            .into(_database.employees)
            .insert(
              EmployeesCompanion.insert(
                employeeNo: employeeNo,
                name: draft.name.trim(),
                gender: values.gender,
                idCardNumber: values.idCardNumber,
                birthDate: values.birthDate,
                phone: values.phone,
                address: values.address,
                hireDate: draft.hireDate,
                status: values.status,
                position: values.position,
                team: values.team,
                workArea: values.workArea,
                manager: values.manager,
                employmentType: values.employmentType,
                defaultAttendanceGroupId: values.defaultAttendanceGroupId,
                remark: values.remark,
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_database.update(
          _database.employees,
        )..where((table) => table.id.equals(id))).write(values);
        employeeId = id;
      }

      await attendanceGroupRepository.syncEmployeeDefaultGroupInTransaction(
        employeeId: employeeId,
        groupId: draft.defaultAttendanceGroupId,
        previousDefaultGroupId: previousEmployee?.defaultAttendanceGroupId,
      );
    });

    final employee = await findById(employeeId);
    if (employee == null) {
      throw StateError('Employee $employeeId was not found after saving.');
    }
    return employee;
  }

  Future<int> softDelete(int id) {
    return _database.softDeleteEmployee(id);
  }

  Future<int> restore(int id) {
    return _database.restoreEmployee(id);
  }

  Future<String> _nextEmployeeNo() async {
    final employees = await (_database.select(_database.employees)).get();
    var largest = 0;
    final pattern = RegExp(r'^EMP-(\d+)$', caseSensitive: false);
    for (final employee in employees) {
      final match = pattern.firstMatch(employee.employeeNo);
      final number = int.tryParse(match?.group(1) ?? '');
      if (number != null && number > largest) {
        largest = number;
      }
    }
    return 'EMP-${(largest + 1).toString().padLeft(4, '0')}';
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
