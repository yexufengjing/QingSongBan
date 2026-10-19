import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../../attendance/domain/monthly_attendance_table_options.dart';
import '../../../core/database/database_enums.dart';
import '../domain/assistant_models.dart';

/// Read-only adapter for local employee resolution and one monthly snapshot.
class AssistantAttendanceReader implements AttendanceReadPort, VehicleReadPort {
  AssistantAttendanceReader(
    this._database, {
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random.secure(),
       _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final Random _random;
  final DateTime Function() _clock;
  final Map<String, int> _candidateEmployeeIds = {};
  final Map<String, int> _candidateVehicleIds = {};
  final Map<String, _VehicleRankingSnapshot> _vehicleRankingSnapshots = {};
  final Map<String, ({String resultRef, int offset})> _vehicleRankingCursors =
      {};

  @override
  Future<EmployeeResolution> resolveEmployee(EmployeeSelector selector) async {
    try {
      return await _database.transaction(() async {
        final month = _normalizeMonth(selector.yearMonth);
        Employee? chosen;
        if (selector.existingEmployee != null) {
          chosen = await _readEmployee(selector.existingEmployee!.employeeId);
          if (chosen == null) return _unavailable();
        } else if (selector.employeeId != null) {
          chosen = await _readEmployee(selector.employeeId!);
          if (chosen == null) return _unavailable();
        } else {
          final queryText = selector.employeeText?.trim() ?? '';
          if (queryText.isEmpty) {
            return const EmployeeResolution(
              status: EmployeeResolutionStatus.notFound,
              error: AssistantErrorCode.missingContext,
            );
          }
          final employees = _database.employees;
          final exact =
              await (_database.select(employees)..where(
                    (table) =>
                        table.isDeleted.equals(false) &
                        (table.employeeNo.equals(queryText) |
                            table.name.equals(queryText)),
                  ))
                  .get();
          final exactNumber = exact
              .where((employee) => employee.employeeNo == queryText)
              .toList();
          final exactNames = exact
              .where((employee) => employee.name == queryText)
              .toList();
          final matches = exactNumber.isNotEmpty
              ? exactNumber
              : exactNames.isNotEmpty
              ? exactNames
              : await (_database.select(employees)..where(
                      (table) =>
                          table.isDeleted.equals(false) &
                          (table.name.like('%$queryText%') |
                              table.employeeNo.like('%$queryText%') |
                              table.team.like('%$queryText%') |
                              table.workArea.like('%$queryText%') |
                              table.position.like('%$queryText%')),
                    ))
                    .get();
          if (matches.isEmpty) {
            return const EmployeeResolution(
              status: EmployeeResolutionStatus.notFound,
              error: AssistantErrorCode.entityNotFound,
            );
          }
          if (matches.length == 1 &&
              (exactNumber.isNotEmpty || exactNames.isNotEmpty)) {
            chosen = matches.single;
          } else {
            final monthRoster = await _readRosterGroups(month, null);
            final candidates = <EmployeeCandidate>[];
            for (final employee in matches) {
              final groupLabels = monthRoster
                  .where((group) => group.employeeId == employee.id)
                  .map((group) => group.groupLabel)
                  .toSet()
                  .toList();
              final ref = _newCandidateRef();
              _candidateEmployeeIds[ref] = employee.id;
              candidates.add(
                EmployeeCandidate(
                  candidateRef: ref,
                  employeeId: employee.id,
                  label: employee.name,
                  employeeNumber: employee.employeeNo,
                  groupLabel: groupLabels.isEmpty
                      ? null
                      : groupLabels.join('、'),
                ),
              );
            }
            return EmployeeResolution(
              status: EmployeeResolutionStatus.candidates,
              candidates: candidates,
            );
          }
        }
        return EmployeeResolution(
          status: EmployeeResolutionStatus.unique,
          employee: ResolvedEmployee(
            employeeId: chosen.id,
            label: chosen.name,
            employeeNumber: chosen.employeeNo,
          ),
        );
      });
    } on FormatException {
      return const EmployeeResolution(
        status: EmployeeResolutionStatus.notFound,
        error: AssistantErrorCode.invalidArgument,
      );
    } catch (_) {
      return const EmployeeResolution(
        status: EmployeeResolutionStatus.unavailable,
        error: AssistantErrorCode.unknown,
      );
    }
  }

  @override
  Future<EmployeeResolution> resolveCandidate(String candidateRef) async {
    final employeeId = _candidateEmployeeIds.remove(candidateRef);
    if (employeeId == null) return _unavailable();
    try {
      return await _database.transaction(() async {
        final employee = await _readEmployee(employeeId);
        if (employee == null) return _unavailable();
        return EmployeeResolution(
          status: EmployeeResolutionStatus.unique,
          employee: ResolvedEmployee(
            employeeId: employee.id,
            label: employee.name,
            employeeNumber: employee.employeeNo,
          ),
        );
      });
    } catch (_) {
      return _unavailable();
    }
  }

  @override
  Future<AttendanceReadResult> readMonth(ResolvedAttendanceQuery query) async {
    final queriedAt = _clock();
    try {
      final month = _normalizeMonth(query.yearMonth);
      final parsedMonth = AppDateUtils.parseYearMonth(month);
      final start = DateTime(parsedMonth.year, parsedMonth.month);
      final next = DateTime(parsedMonth.year, parsedMonth.month + 1);
      return await _database.transaction(() async {
        final employee = await _readEmployee(query.employee.employeeId);
        if (employee == null) {
          return _emptyResult(
            query,
            queriedAt,
            AttendanceReadStatus.employeeUnavailable,
            AssistantErrorCode.entityUnavailable,
          );
        }

        final rosterGroups = await _readRosterGroups(month, employee.id);
        if (rosterGroups.isEmpty) {
          return _emptyResult(
            query,
            queriedAt,
            AttendanceReadStatus.notInRoster,
            AssistantErrorCode.notInRoster,
          );
        }
        final selectedGroups = query.groupId == null
            ? rosterGroups
            : rosterGroups
                  .where((group) => group.groupId == query.groupId)
                  .toList();
        // An unavailable page group must not silently replace a historical
        // roster. The verified monthly roster is the authoritative source.
        final groups = selectedGroups.isEmpty ? rosterGroups : selectedGroups;

        final terminations =
            await (_database.select(_database.terminationRecords)..where(
                  (table) =>
                      table.employeeId.equals(employee.id) &
                      table.isDeleted.equals(false),
                ))
                .get();
        final terminationDates = terminations
            .map((record) => AppDateUtils.dateOnly(record.terminationDate))
            .toSet();
        if (terminationDates.length > 1) {
          return _emptyResult(
            query,
            queriedAt,
            AttendanceReadStatus.dataConflict,
            AssistantErrorCode.dataConflict,
            groupLabels: groups
                .map((group) => group.groupLabel)
                .toSet()
                .toList(),
            groupIds: groups.map((group) => group.groupId).toSet().toList(),
          );
        }
        final terminationDate = terminationDates.isEmpty
            ? null
            : terminationDates.single;
        final records =
            await (_database.select(_database.attendanceRecords)..where(
                  (table) =>
                      table.employeeId.equals(employee.id) &
                      table.attendanceDate.isBiggerOrEqualValue(start) &
                      table.attendanceDate.isSmallerThanValue(next) &
                      table.isDeleted.equals(false),
                ))
                .get();

        final row = MonthlyAttendanceTableRow(
          employee: employee,
          terminationDate: terminationDate,
        );
        for (final record in records) {
          row.addRecord(record);
        }
        final dailyDetails = <AttendanceDayDetail>[];
        for (
          var day = 1;
          day <= DateTime(parsedMonth.year, parsedMonth.month + 1, 0).day;
          day++
        ) {
          final cell = row.cellForDay(month: start, day: day);
          dailyDetails.add(
            AttendanceDayDetail(
              date: cell.date,
              morningStatus: monthlyAttendanceStatusLabel(cell.morningStatus),
              afternoonStatus: monthlyAttendanceStatusLabel(
                cell.afternoonStatus,
              ),
            ),
          );
        }
        final overtime =
            await (_database.select(_database.overtimeRecords)
                  ..where(
                    (table) =>
                        table.employeeId.equals(employee.id) &
                        table.overtimeDate.isBiggerOrEqualValue(start) &
                        table.overtimeDate.isSmallerThanValue(next) &
                        table.isDeleted.equals(false),
                  )
                  ..orderBy([
                    (table) => OrderingTerm(expression: table.overtimeDate),
                  ]))
                .get();
        final overtimeMinutes = overtime.fold<int>(
          0,
          (sum, record) => sum + record.durationMinutes,
        );
        return AttendanceReadResult(
          status: AttendanceReadStatus.success,
          employeeLabel: employee.name,
          yearMonth: month,
          queriedAt: queriedAt,
          completeness: AttendanceCompleteness.notEvaluated,
          groupLabels: groups.map((group) => group.groupLabel).toSet().toList(),
          groupIds: groups.map((group) => group.groupId).toSet().toList(),
          attendanceDays: row.attendanceDays,
          leaveAndRestDays: row.leaveDays,
          overtimeMinutes: overtimeMinutes,
          details: AttendanceLocalDetails(
            attendanceDaysByDate: dailyDetails,
            overtime: [
              for (final record in overtime)
                OvertimeDetail(
                  date: record.overtimeDate,
                  durationMinutes: record.durationMinutes,
                ),
            ],
          ),
        );
      });
    } on FormatException {
      return _emptyResult(
        query,
        queriedAt,
        AttendanceReadStatus.failure,
        AssistantErrorCode.invalidArgument,
      );
    } catch (_) {
      return _emptyResult(
        query,
        queriedAt,
        AttendanceReadStatus.failure,
        AssistantErrorCode.unknown,
      );
    }
  }

  @override
  Future<VehicleResolution> resolveVehicle(VehicleSelector selector) async {
    try {
      return await _database.transaction(() async {
        Vehicle? chosen;
        if (selector.existingVehicle != null) {
          chosen = await _readVehicle(selector.existingVehicle!.vehicleId);
          if (chosen == null) return _vehicleUnavailable();
        } else if (selector.vehicleId != null) {
          chosen = await _readVehicle(selector.vehicleId!);
          if (chosen == null) return _vehicleUnavailable();
        } else {
          final query = selector.vehicleText?.trim() ?? '';
          if (query.isEmpty) {
            return const VehicleResolution(
              status: VehicleResolutionStatus.notFound,
              error: AssistantErrorCode.missingContext,
            );
          }
          final vehicles = _database.vehicles;
          final active = _database.select(vehicles)
            ..where((table) => table.isDeleted.equals(false));
          final rows = await active.get();
          final byNumber = rows.where((row) => row.vehicleNo == query).toList();
          final byPlate = rows
              .where((row) => row.licensePlate == query)
              .toList();
          final byName = rows.where((row) => row.name == query).toList();
          final exact = byNumber.isNotEmpty
              ? byNumber
              : byPlate.isNotEmpty
              ? byPlate
              : byName;
          final matches = exact.isNotEmpty
              ? exact
              : rows
                    .where(
                      (row) =>
                          row.name.contains(query) ||
                          row.vehicleNo.contains(query) ||
                          (row.licensePlate?.contains(query) ?? false),
                    )
                    .toList();
          if (matches.isEmpty) {
            return const VehicleResolution(
              status: VehicleResolutionStatus.notFound,
              error: AssistantErrorCode.entityNotFound,
            );
          }
          if (matches.length == 1 && exact.isNotEmpty) {
            chosen = matches.single;
          } else {
            final candidates = <VehicleCandidate>[];
            for (final vehicle in matches) {
              final candidateRef = _newCandidateRef();
              _candidateVehicleIds[candidateRef] = vehicle.id;
              candidates.add(
                VehicleCandidate(
                  candidateRef: candidateRef,
                  vehicleId: vehicle.id,
                  label: vehicle.name,
                  vehicleNumber: vehicle.vehicleNo,
                ),
              );
            }
            return VehicleResolution(
              status: VehicleResolutionStatus.candidates,
              candidates: candidates,
            );
          }
        }
        return VehicleResolution(
          status: VehicleResolutionStatus.unique,
          vehicle: _resolvedVehicle(chosen),
        );
      });
    } catch (_) {
      return _vehicleUnavailable();
    }
  }

  @override
  Future<VehicleResolution> resolveVehicleCandidate(String candidateRef) async {
    final vehicleId = _candidateVehicleIds.remove(candidateRef);
    if (vehicleId == null) return _vehicleUnavailable();
    try {
      return await _database.transaction(() async {
        final vehicle = await _readVehicle(vehicleId);
        if (vehicle == null) return _vehicleUnavailable();
        return VehicleResolution(
          status: VehicleResolutionStatus.unique,
          vehicle: _resolvedVehicle(vehicle),
        );
      });
    } catch (_) {
      return _vehicleUnavailable();
    }
  }

  @override
  Future<VehicleAnnualRepairResult> readVehicleAnnualRepairs(
    ResolvedVehicleAnnualRepairQuery query,
  ) async {
    final queriedAt = _clock();
    if (query.year < 1 || query.year > 9999) {
      return _vehicleSummaryError(
        query,
        queriedAt,
        AssistantErrorCode.invalidArgument,
      );
    }
    try {
      return await _database.transaction(() async {
        final vehicle = await _readVehicle(query.vehicle.vehicleId);
        if (vehicle == null) {
          return _vehicleSummaryError(
            query,
            queriedAt,
            AssistantErrorCode.entityUnavailable,
            status: VehicleAnnualRepairReadStatus.unavailable,
          );
        }
        final orders =
            await (_database.select(_database.repairOrders)
                  ..where(
                    (table) =>
                        table.vehicleId.equals(vehicle.id) &
                        table.isDeleted.equals(false) &
                        table.status.equalsValue(
                          VehicleRepairStatus.completed,
                        ) &
                        table.reportDate.isBiggerOrEqualValue(
                          DateTime(query.year),
                        ) &
                        table.reportDate.isSmallerThanValue(
                          DateTime(query.year + 1),
                        ),
                  )
                  ..orderBy([
                    (table) => OrderingTerm(expression: table.reportDate),
                    (table) => OrderingTerm(expression: table.id),
                  ]))
                .get();
        return VehicleAnnualRepairResult(
          status: orders.isEmpty
              ? VehicleAnnualRepairReadStatus.empty
              : VehicleAnnualRepairReadStatus.success,
          vehicle: _resolvedVehicle(vehicle),
          year: query.year,
          queriedAt: queriedAt,
          completedRepairCount: orders.length,
          actualAmountCents: orders.fold<int>(
            0,
            (sum, order) => sum + order.actualAmountCents,
          ),
          resultRef: _newCandidateRef(),
          details: orders
              .map(
                (order) => VehicleRepairLocalDetail(
                  repairOrderId: order.id,
                  reportDate: order.reportDate,
                  completedAt: order.completedAt,
                  actualAmountCents: order.actualAmountCents,
                ),
              )
              .toList(growable: false),
        );
      });
    } catch (_) {
      return _vehicleSummaryError(query, queriedAt, AssistantErrorCode.unknown);
    }
  }

  @override
  Future<VehicleRankingPage> readAnnualVehicleRanking(
    ResolvedVehicleRankingQuery query,
  ) async {
    if (query.year < 1 || query.year > 9999) {
      return _rankingError(query.year, AssistantErrorCode.invalidArgument);
    }
    try {
      final snapshot = await _database.transaction(() async {
        final vehicles = await (_database.select(
          _database.vehicles,
        )..where((table) => table.isDeleted.equals(false))).get();
        final orders =
            await (_database.select(_database.repairOrders)..where(
                  (table) =>
                      table.isDeleted.equals(false) &
                      table.status.equalsValue(VehicleRepairStatus.completed) &
                      table.reportDate.isBiggerOrEqualValue(
                        DateTime(query.year),
                      ) &
                      table.reportDate.isSmallerThanValue(
                        DateTime(query.year + 1),
                      ),
                ))
                .get();
        final activeIds = vehicles.map((vehicle) => vehicle.id).toSet();
        final orderGroups = <int, List<RepairOrder>>{};
        for (final order in orders) {
          if (!activeIds.contains(order.vehicleId)) continue;
          orderGroups.putIfAbsent(order.vehicleId, () => []).add(order);
        }
        final sorted =
            vehicles.map((vehicle) {
              final repairs = orderGroups[vehicle.id] ?? const <RepairOrder>[];
              return (
                vehicle: vehicle,
                count: repairs.length,
                amount: repairs.fold<int>(
                  0,
                  (sum, order) => sum + order.actualAmountCents,
                ),
              );
            }).toList()..sort((a, b) {
              final byAmount = b.amount.compareTo(a.amount);
              if (byAmount != 0) return byAmount;
              final byNumber = a.vehicle.vehicleNo.compareTo(
                b.vehicle.vehicleNo,
              );
              return byNumber != 0
                  ? byNumber
                  : a.vehicle.id.compareTo(b.vehicle.id);
            });
        var previousAmount = -1;
        var rank = 0;
        final rows = <VehicleRankingRow>[];
        for (var index = 0; index < sorted.length; index++) {
          final item = sorted[index];
          if (item.amount != previousAmount) rank = index + 1;
          previousAmount = item.amount;
          rows.add(
            VehicleRankingRow(
              vehicleId: item.vehicle.id,
              vehicleLabel: item.vehicle.name,
              vehicleNumber: item.vehicle.vehicleNo,
              rank: rank,
              completedRepairCount: item.count,
              actualAmountCents: item.amount,
              alias: 'V${(index + 1).toString().padLeft(3, '0')}',
            ),
          );
        }
        return rows;
      });
      final resultRef = _newCandidateRef();
      _vehicleRankingSnapshots[resultRef] = _VehicleRankingSnapshot(
        year: query.year,
        limit: query.limit.clamp(1, 50),
        queriedAt: _clock(),
        rows: snapshot,
      );
      return _vehicleRankingPage(resultRef, 0, query.limit);
    } catch (_) {
      return _rankingError(query.year, AssistantErrorCode.unknown);
    }
  }

  @override
  Future<VehicleRankingPage> readNextVehicleRankingPage({
    required String resultRef,
    required String cursor,
  }) async {
    final binding = _vehicleRankingCursors.remove(cursor);
    if (binding == null || binding.resultRef != resultRef) {
      final snapshot = _vehicleRankingSnapshots[resultRef];
      return VehicleRankingPage(
        resultRef: resultRef,
        year: snapshot?.year ?? _clock().year,
        queriedAt: _clock(),
        rows: const [],
        totalVehicleCount: snapshot?.rows.length ?? 0,
        returnedCount: 0,
        hasMore: false,
        error: AssistantErrorCode.staleResult,
      );
    }
    return _vehicleRankingPage(
      resultRef,
      binding.offset,
      _vehicleRankingSnapshots[resultRef]?.limit ?? 10,
    );
  }

  VehicleRankingPage _vehicleRankingPage(
    String resultRef,
    int offset,
    int requestedLimit,
  ) {
    final snapshot = _vehicleRankingSnapshots[resultRef];
    if (snapshot == null || offset < 0 || offset > snapshot.rows.length) {
      return _rankingError(_clock().year, AssistantErrorCode.staleResult);
    }
    final limit = requestedLimit.clamp(1, 50);
    final end = (offset + limit).clamp(0, snapshot.rows.length);
    final hasMore = end < snapshot.rows.length;
    final cursor = hasMore ? _newCandidateRef() : null;
    if (cursor != null) {
      _vehicleRankingCursors[cursor] = (resultRef: resultRef, offset: end);
    }
    return VehicleRankingPage(
      resultRef: resultRef,
      year: snapshot.year,
      queriedAt: snapshot.queriedAt,
      rows: snapshot.rows.sublist(offset, end),
      totalVehicleCount: snapshot.rows.length,
      returnedCount: end,
      hasMore: hasMore,
      hasRepairRecords: snapshot.rows.any(
        (row) => row.completedRepairCount > 0,
      ),
      nextCursor: cursor,
    );
  }

  Future<Vehicle?> _readVehicle(int id) =>
      (_database.select(_database.vehicles)..where(
            (table) => table.id.equals(id) & table.isDeleted.equals(false),
          ))
          .getSingleOrNull();

  ResolvedVehicle _resolvedVehicle(Vehicle vehicle) => ResolvedVehicle(
    vehicleId: vehicle.id,
    label: vehicle.name,
    vehicleNumber: vehicle.vehicleNo,
  );

  VehicleResolution _vehicleUnavailable() => const VehicleResolution(
    status: VehicleResolutionStatus.unavailable,
    error: AssistantErrorCode.entityUnavailable,
  );

  VehicleAnnualRepairResult _vehicleSummaryError(
    ResolvedVehicleAnnualRepairQuery query,
    DateTime queriedAt,
    AssistantErrorCode error, {
    VehicleAnnualRepairReadStatus status =
        VehicleAnnualRepairReadStatus.failure,
  }) => VehicleAnnualRepairResult(
    status: status,
    vehicle: query.vehicle,
    year: query.year,
    queriedAt: queriedAt,
    completedRepairCount: 0,
    actualAmountCents: 0,
    error: error,
  );

  VehicleRankingPage _rankingError(int year, AssistantErrorCode error) =>
      VehicleRankingPage(
        resultRef: '',
        year: year,
        queriedAt: _clock(),
        rows: const [],
        totalVehicleCount: 0,
        returnedCount: 0,
        hasMore: false,
        error: error,
      );

  Future<Employee?> _readEmployee(int id) async {
    final employee =
        await (_database.select(_database.employees)..where(
              (table) => table.id.equals(id) & table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    return employee;
  }

  Future<List<_RosterGroup>> _readRosterGroups(
    String month,
    int? employeeId,
  ) async {
    final rosters = _database.monthlyAttendanceRosters;
    final groups = _database.attendanceGroups;
    final query =
        _database.select(rosters).join([
          innerJoin(groups, groups.id.equalsExp(rosters.attendanceGroupId)),
        ])..where(
          rosters.yearMonth.equals(month) &
              rosters.isActive.equals(true) &
              rosters.isDeleted.equals(false) &
              groups.isDeleted.equals(false) &
              (employeeId == null
                  ? const Constant(true)
                  : rosters.employeeId.equals(employeeId)),
        );
    final rows = await query.get();
    return [
      for (final row in rows)
        _RosterGroup(
          employeeId: row.readTable(rosters).employeeId,
          groupId: row.readTable(rosters).attendanceGroupId,
          groupLabel: row.readTable(groups).name,
        ),
    ];
  }

  String _newCandidateRef() => List<String>.generate(
    4,
    (_) => _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
  ).join();

  String _normalizeMonth(String value) =>
      AppDateUtils.yearMonth(AppDateUtils.parseYearMonth(value));

  EmployeeResolution _unavailable() => const EmployeeResolution(
    status: EmployeeResolutionStatus.unavailable,
    error: AssistantErrorCode.entityUnavailable,
  );

  AttendanceReadResult _emptyResult(
    ResolvedAttendanceQuery query,
    DateTime queriedAt,
    AttendanceReadStatus status,
    AssistantErrorCode error, {
    List<String> groupLabels = const [],
    List<int> groupIds = const [],
  }) => AttendanceReadResult(
    status: status,
    employeeLabel: query.employee.label,
    yearMonth: query.yearMonth,
    queriedAt: queriedAt,
    completeness: AttendanceCompleteness.notEvaluated,
    groupLabels: groupLabels,
    groupIds: groupIds,
    error: error,
  );
}

class _RosterGroup {
  const _RosterGroup({
    required this.employeeId,
    required this.groupId,
    required this.groupLabel,
  });

  final int employeeId;
  final int groupId;
  final String groupLabel;
}

class _VehicleRankingSnapshot {
  const _VehicleRankingSnapshot({
    required this.year,
    required this.limit,
    required this.queriedAt,
    required this.rows,
  });

  final int year;
  final int limit;
  final DateTime queriedAt;
  final List<VehicleRankingRow> rows;
}
