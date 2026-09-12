import 'package:drift/drift.dart';

import '../../../core/constants/database_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/monthly_roster_options.dart';

class MonthlyRosterRepository {
  const MonthlyRosterRepository(this._database);

  final AppDatabase _database;

  Stream<List<MonthlyRosterEntryView>> watchRoster({
    required String yearMonth,
    required int groupId,
    bool includeRemoved = false,
  }) {
    final normalizedMonth = _normalizeMonth(yearMonth);
    final rosters = _database.monthlyAttendanceRosters;
    final employees = _database.employees;
    final query =
        _database.select(rosters).join([
            innerJoin(employees, employees.id.equalsExp(rosters.employeeId)),
          ])
          ..where(
            rosters.yearMonth.equals(normalizedMonth) &
                rosters.attendanceGroupId.equals(groupId) &
                rosters.isDeleted.equals(false) &
                employees.isDeleted.equals(false) &
                (includeRemoved
                    ? const Constant(true)
                    : rosters.isActive.equals(true)),
          )
          ..orderBy([
            OrderingTerm(expression: employees.name),
            OrderingTerm(expression: employees.employeeNo),
          ]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          MonthlyRosterEntryView(
            roster: row.readTable(rosters),
            employee: row.readTable(employees),
          ),
      ],
    );
  }

  Stream<MonthlyRosterCounts> watchCounts({
    required String yearMonth,
    required int groupId,
  }) {
    final normalizedMonth = _normalizeMonth(yearMonth);
    final query = _database.select(_database.monthlyAttendanceRosters)
      ..where(
        (table) =>
            table.yearMonth.equals(normalizedMonth) &
            table.attendanceGroupId.equals(groupId) &
            table.isDeleted.equals(false),
      );
    return query.watch().map(
      (rows) => MonthlyRosterCounts(
        activeCount: rows.where((row) => row.isActive).length,
        removedCount: rows.where((row) => !row.isActive).length,
      ),
    );
  }

  Stream<List<Employee>> watchEligibleEmployees({required String yearMonth}) {
    final monthEndExclusive = _monthStartNext(yearMonth);
    final query = _database.select(_database.employees)
      ..where(
        (table) =>
            table.isDeleted.equals(false) &
            table.hireDate.isSmallerThanValue(monthEndExclusive),
      )
      ..orderBy([
        (table) => OrderingTerm(expression: table.name),
        (table) => OrderingTerm(expression: table.employeeNo),
      ]);
    return query.watch();
  }

  Future<MonthlyAttendanceRoster?> findEntry({
    required String yearMonth,
    required int groupId,
    required int employeeId,
  }) {
    final normalizedMonth = _normalizeMonth(yearMonth);
    return (_database.select(_database.monthlyAttendanceRosters)..where(
          (table) =>
              table.yearMonth.equals(normalizedMonth) &
              table.attendanceGroupId.equals(groupId) &
              table.employeeId.equals(employeeId),
        ))
        .getSingleOrNull();
  }

  Future<int> addEmployee({
    required String yearMonth,
    required int groupId,
    required int employeeId,
  }) async {
    final normalizedMonth = _normalizeMonth(yearMonth);
    await _requireEnabledGroup(groupId);
    await _requireEligibleEmployee(employeeId, normalizedMonth);
    return _database.transaction(
      () => _upsertRoster(
        yearMonth: normalizedMonth,
        groupId: groupId,
        employeeId: employeeId,
        source: DatabaseConstants.manualRosterSource,
      ),
    );
  }

  Future<int> removeEmployee({
    required String yearMonth,
    required int groupId,
    required int employeeId,
  }) async {
    final normalizedMonth = _normalizeMonth(yearMonth);
    final now = DateTime.now();
    return (_database.update(_database.monthlyAttendanceRosters)..where(
          (table) =>
              table.yearMonth.equals(normalizedMonth) &
              table.attendanceGroupId.equals(groupId) &
              table.employeeId.equals(employeeId) &
              table.isDeleted.equals(false) &
              table.isActive.equals(true),
        ))
        .write(
          MonthlyAttendanceRostersCompanion(
            isActive: const Value(false),
            updatedAt: Value(now),
          ),
        );
  }

  Future<int> restoreEmployee({
    required String yearMonth,
    required int groupId,
    required int employeeId,
  }) async {
    final normalizedMonth = _normalizeMonth(yearMonth);
    await _requireEnabledGroup(groupId);
    await _requireEligibleEmployee(employeeId, normalizedMonth);
    return _database.transaction(
      () => _upsertRoster(
        yearMonth: normalizedMonth,
        groupId: groupId,
        employeeId: employeeId,
        source: DatabaseConstants.manualRosterSource,
      ),
    );
  }

  Future<int> addDefaultGroupEmployees({
    required String yearMonth,
    required int groupId,
  }) async {
    final normalizedMonth = _normalizeMonth(yearMonth);
    await _requireEnabledGroup(groupId);
    final employees =
        await (_database.select(_database.employees)..where(
              (table) =>
                  table.isDeleted.equals(false) &
                  table.defaultAttendanceGroupId.equals(groupId) &
                  table.hireDate.isSmallerThanValue(
                    _monthStartNext(normalizedMonth),
                  ),
            ))
            .get();

    return _database.transaction(() async {
      var count = 0;
      for (final employee in employees) {
        count += await _upsertRoster(
          yearMonth: normalizedMonth,
          groupId: groupId,
          employeeId: employee.id,
          source: DatabaseConstants.manualRosterSource,
        );
      }
      return count;
    });
  }

  Future<MonthlyRosterCopyResult> copyFromPreviousMonth({
    required String yearMonth,
    required int groupId,
  }) async {
    final normalizedMonth = _normalizeMonth(yearMonth);
    await _requireEnabledGroup(groupId);
    final sourceDate = DateTime(
      AppDateUtils.parseYearMonth(normalizedMonth).year,
      AppDateUtils.parseYearMonth(normalizedMonth).month,
      1,
    ).subtract(const Duration(days: 1));
    final sourceYearMonth = AppDateUtils.yearMonth(sourceDate);
    final sourceRows =
        await (_database.select(_database.monthlyAttendanceRosters)..where(
              (table) =>
                  table.yearMonth.equals(sourceYearMonth) &
                  table.attendanceGroupId.equals(groupId) &
                  table.isDeleted.equals(false) &
                  table.isActive.equals(true),
            ))
            .get();

    return _database.transaction(() async {
      var count = 0;
      for (final row in sourceRows) {
        final employee = await _requireEligibleEmployee(
          row.employeeId,
          normalizedMonth,
        );
        if (employee != null) {
          count += await _upsertRoster(
            yearMonth: normalizedMonth,
            groupId: groupId,
            employeeId: row.employeeId,
            source: DatabaseConstants.copiedRosterSource,
            preserveActiveSource: true,
          );
        }
      }
      return MonthlyRosterCopyResult(
        sourceYearMonth: sourceYearMonth,
        count: count,
      );
    });
  }

  Future<AttendanceGroup?> findGroup(int groupId) {
    return (_database.select(_database.attendanceGroups)..where(
          (table) => table.id.equals(groupId) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<AttendanceGroup> _requireEnabledGroup(int groupId) async {
    final group = await findGroup(groupId);
    if (group == null) {
      throw StateError('考勤组不存在或已被移除');
    }
    if (!group.isEnabled) {
      throw StateError('停用的考勤组不能新增月度考勤名单');
    }
    return group;
  }

  Future<Employee?> _requireEligibleEmployee(
    int employeeId,
    String yearMonth,
  ) async {
    final employee = await _database.findEmployeeById(employeeId);
    if (employee == null || employee.isDeleted) {
      throw StateError('人员不存在或已被移除');
    }
    if (AppDateUtils.dateOnly(employee.hireDate)
        .isAfter(_monthEnd(yearMonth))) {
      throw StateError('人员入职日期晚于所选月份，不能加入月度名单');
    }
    return employee;
  }

  Future<int> _upsertRoster({
    required String yearMonth,
    required int groupId,
    required int employeeId,
    required String source,
    bool preserveActiveSource = false,
  }) async {
    final now = DateTime.now();
    final existing = await findEntry(
      yearMonth: yearMonth,
      groupId: groupId,
      employeeId: employeeId,
    );
    if (existing == null) {
      await _database
          .into(_database.monthlyAttendanceRosters)
          .insert(
            MonthlyAttendanceRostersCompanion.insert(
              yearMonth: yearMonth,
              attendanceGroupId: groupId,
              employeeId: employeeId,
              isActive: const Value(true),
              source: Value(source),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return 1;
    }

    if (existing.isActive && !existing.isDeleted) {
      if (preserveActiveSource) {
        return 0;
      }
      await (_database.update(
        _database.monthlyAttendanceRosters,
      )..where((table) => table.id.equals(existing.id))).write(
        MonthlyAttendanceRostersCompanion(
          source: Value(source),
          updatedAt: Value(now),
        ),
      );
      return 0;
    }

    await (_database.update(
      _database.monthlyAttendanceRosters,
    )..where((table) => table.id.equals(existing.id))).write(
      MonthlyAttendanceRostersCompanion(
        isActive: const Value(true),
        isDeleted: const Value(false),
        source: Value(source),
        updatedAt: Value(now),
      ),
    );
    return 1;
  }

  String _normalizeMonth(String value) {
    return AppDateUtils.yearMonth(AppDateUtils.parseYearMonth(value));
  }

  DateTime _monthEnd(String yearMonth) {
    final month = AppDateUtils.parseYearMonth(yearMonth);
    return DateTime(month.year, month.month + 1, 0);
  }

  DateTime _monthStartNext(String yearMonth) {
    final month = AppDateUtils.parseYearMonth(yearMonth);
    return DateTime(month.year, month.month + 1);
  }
}
