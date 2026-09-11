import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../domain/attendance_group_options.dart';

class AttendanceGroupRepository {
  const AttendanceGroupRepository(this._database);

  final AppDatabase _database;

  Stream<List<AttendanceGroupSummary>> watchGroupSummaries({
    bool includeDisabled = true,
  }) {
    final groups = _database.attendanceGroups;
    final members = _database.attendanceGroupMembers;
    final employees = _database.employees;
    final query =
        _database.select(groups).join([
            leftOuterJoin(
              members,
              members.attendanceGroupId.equalsExp(groups.id) &
                  members.isDeleted.equals(false),
            ),
            leftOuterJoin(
              employees,
              employees.id.equalsExp(members.employeeId) &
                  employees.isDeleted.equals(false),
            ),
          ])
          ..where(
            groups.isDeleted.equals(false) &
                (includeDisabled
                    ? const Constant(true)
                    : groups.isEnabled.equals(true)),
          )
          ..orderBy([
            OrderingTerm(expression: groups.sortOrder),
            OrderingTerm(expression: groups.name),
          ]);

    return query.watch().map((rows) {
      final summaries = <int, AttendanceGroupSummary>{};
      for (final row in rows) {
        final group = row.readTable(groups);
        final employee = row.readTableOrNull(employees);
        final current = summaries[group.id];
        summaries[group.id] = AttendanceGroupSummary(
          group: group,
          memberCount: (current?.memberCount ?? 0) + (employee == null ? 0 : 1),
        );
      }
      return summaries.values.toList();
    });
  }

  Stream<List<AttendanceGroup>> watchEnabledGroups() {
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

  Future<AttendanceGroup?> findById(int id) {
    return (_database.select(_database.attendanceGroups)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<AttendanceGroup> save({
    int? id,
    required AttendanceGroupDraft draft,
  }) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw const FormatException('请填写考勤组名称');
    }

    final existingGroups = await (_database.select(
      _database.attendanceGroups,
    )..where((table) => table.isDeleted.equals(false))).get();
    final duplicate = existingGroups.any(
      (group) =>
          group.id != id &&
          group.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      throw const FormatException('考勤组名称已存在');
    }

    final now = DateTime.now();
    if (id == null) {
      final groupId = await _database
          .into(_database.attendanceGroups)
          .insert(
            AttendanceGroupsCompanion.insert(
              name: name,
              groupType: Value(draft.groupType),
              isEnabled: Value(draft.isEnabled),
              sortOrder: Value(draft.sortOrder),
              remark: Value(_nullableText(draft.remark)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      final group = await findById(groupId);
      if (group == null) {
        throw StateError(
          'Attendance group $groupId was not found after saving.',
        );
      }
      return group;
    }

    final updated =
        await (_database.update(_database.attendanceGroups)..where(
              (table) => table.id.equals(id) & table.isDeleted.equals(false),
            ))
            .write(
              AttendanceGroupsCompanion(
                name: Value(name),
                groupType: Value(draft.groupType),
                isEnabled: Value(draft.isEnabled),
                sortOrder: Value(draft.sortOrder),
                remark: Value(_nullableText(draft.remark)),
                updatedAt: Value(now),
              ),
            );
    if (updated == 0) {
      throw StateError('考勤组不存在或已被移除');
    }
    final group = await findById(id);
    if (group == null) {
      throw StateError('Attendance group $id was not found after saving.');
    }
    return group;
  }

  Future<void> setEnabled(int id, bool enabled) async {
    final updated =
        await (_database.update(_database.attendanceGroups)..where(
              (table) => table.id.equals(id) & table.isDeleted.equals(false),
            ))
            .write(
              AttendanceGroupsCompanion(
                isEnabled: Value(enabled),
                updatedAt: Value(DateTime.now()),
              ),
            );
    if (updated == 0) {
      throw StateError('考勤组不存在或已被移除');
    }
  }

  Stream<List<AttendanceGroupMemberView>> watchMembers(int groupId) {
    final members = _database.attendanceGroupMembers;
    final employees = _database.employees;
    final query =
        _database.select(members).join([
            innerJoin(employees, employees.id.equalsExp(members.employeeId)),
          ])
          ..where(
            members.attendanceGroupId.equals(groupId) &
                members.isDeleted.equals(false) &
                employees.isDeleted.equals(false),
          )
          ..orderBy([OrderingTerm(expression: employees.name)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          AttendanceGroupMemberView(
            membership: row.readTable(members),
            employee: row.readTable(employees),
          ),
      ],
    );
  }

  Stream<List<Employee>> watchAssignableEmployees() {
    final query = _database.select(_database.employees)
      ..where(
        (table) =>
            table.isDeleted.equals(false) &
                table.status.equalsValue(EmployeeStatus.active) |
            (table.isDeleted.equals(false) &
                table.status.equalsValue(EmployeeStatus.paused)),
      )
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);
    return query.watch();
  }

  Future<void> assignEmployeeToGroup({
    required int employeeId,
    required int groupId,
  }) async {
    await _database.transaction(() async {
      final employee = await _database.findEmployeeById(employeeId);
      if (employee == null || employee.isDeleted) {
        throw StateError('人员不存在或已被移除');
      }
      await _syncEmployeeDefaultGroupInTransaction(
        employeeId: employeeId,
        groupId: groupId,
        previousDefaultGroupId: employee.defaultAttendanceGroupId,
      );
    });
  }

  Future<void> clearEmployeeFromGroup({
    required int employeeId,
    required int groupId,
  }) async {
    await _database.transaction(() async {
      final employee = await _database.findEmployeeById(employeeId);
      if (employee == null || employee.isDeleted) {
        throw StateError('人员不存在或已被移除');
      }
      if (employee.defaultAttendanceGroupId != groupId) {
        return;
      }
      await _syncEmployeeDefaultGroupInTransaction(
        employeeId: employeeId,
        groupId: null,
        previousDefaultGroupId: employee.defaultAttendanceGroupId,
      );
    });
  }

  /// Called by personnel saving while the employee and membership updates
  /// are already inside the same Drift transaction.
  Future<void> syncEmployeeDefaultGroupInTransaction({
    required int employeeId,
    required int? groupId,
    required int? previousDefaultGroupId,
  }) {
    return _syncEmployeeDefaultGroupInTransaction(
      employeeId: employeeId,
      groupId: groupId,
      previousDefaultGroupId: previousDefaultGroupId,
    );
  }

  Future<void> _syncEmployeeDefaultGroupInTransaction({
    required int employeeId,
    required int? groupId,
    required int? previousDefaultGroupId,
  }) async {
    if (groupId != null) {
      final group =
          await (_database.select(_database.attendanceGroups)..where(
                (table) =>
                    table.id.equals(groupId) & table.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      if (group == null) {
        throw StateError('考勤组不存在或已被移除');
      }
      if (!group.isEnabled && groupId != previousDefaultGroupId) {
        throw StateError('停用的考勤组不能作为新的默认考勤组');
      }
    }

    final now = DateTime.now();
    await (_database.update(_database.attendanceGroupMembers)..where(
          (table) =>
              table.employeeId.equals(employeeId) &
              table.isDeleted.equals(false),
        ))
        .write(
          AttendanceGroupMembersCompanion(
            isDeleted: const Value(true),
            isDefault: const Value(false),
            updatedAt: Value(now),
          ),
        );

    if (groupId != null) {
      final existing =
          await (_database.select(_database.attendanceGroupMembers)..where(
                (table) =>
                    table.attendanceGroupId.equals(groupId) &
                    table.employeeId.equals(employeeId),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await _database
            .into(_database.attendanceGroupMembers)
            .insert(
              AttendanceGroupMembersCompanion.insert(
                attendanceGroupId: groupId,
                employeeId: employeeId,
                isDefault: const Value(true),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_database.update(
          _database.attendanceGroupMembers,
        )..where((table) => table.id.equals(existing.id))).write(
          AttendanceGroupMembersCompanion(
            isDefault: const Value(true),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }
    }

    await (_database.update(
      _database.employees,
    )..where((table) => table.id.equals(employeeId))).write(
      EmployeesCompanion(
        defaultAttendanceGroupId: Value(groupId),
        updatedAt: Value(now),
      ),
    );
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
