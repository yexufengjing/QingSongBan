import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/overtime_options.dart';

class OvertimeRepository {
  const OvertimeRepository(this._database);

  final AppDatabase _database;

  Stream<List<OvertimeRecordView>> watchOvertime({DateTime? month}) {
    final overtime = _database.overtimeRecords;
    final employees = _database.employees;
    final query =
        _database.select(overtime).join([
          innerJoin(employees, employees.id.equalsExp(overtime.employeeId)),
        ])..where(
          overtime.isDeleted.equals(false) & employees.isDeleted.equals(false),
        );
    if (month != null) {
      final firstDay = DateTime(month.year, month.month);
      final lastDay = DateTime(month.year, month.month + 1, 0);
      query.where(
        overtime.overtimeDate.isBiggerOrEqualValue(firstDay) &
            overtime.overtimeDate.isSmallerOrEqualValue(lastDay),
      );
    }
    query.orderBy([
      OrderingTerm(expression: overtime.overtimeDate, mode: OrderingMode.desc),
      OrderingTerm(expression: overtime.startTime, mode: OrderingMode.desc),
      OrderingTerm(expression: employees.name),
    ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          OvertimeRecordView(
            overtime: row.readTable(overtime),
            employee: row.readTable(employees),
          ),
      ],
    );
  }

  Future<OvertimeRecord?> findById(int id) {
    return (_database.select(_database.overtimeRecords)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<OvertimeRecord> save({
    int? id,
    required OvertimeRecordDraft draft,
  }) async {
    final overtimeDate = AppDateUtils.dateOnly(draft.overtimeDate);
    final startTime = _normalizeTime(draft.startTime, overtimeDate);
    final endTime = _normalizeTime(draft.endTime, overtimeDate);
    final durationMinutes = endTime.difference(startTime).inMinutes;
    if (durationMinutes <= 0) {
      throw const FormatException('结束时间必须晚于开始时间');
    }

    final employee = await _database.findEmployeeById(draft.employeeId);
    if (employee == null || employee.isDeleted) {
      throw StateError('人员不存在或已被移除');
    }
    final previous = id == null ? null : await findById(id);
    if (id != null && previous == null) {
      throw StateError('加班记录不存在或已被删除');
    }
    final existing =
        await (_database.select(_database.overtimeRecords)..where(
              (table) =>
                  table.employeeId.equals(draft.employeeId) &
                  table.overtimeDate.equals(overtimeDate) &
                  table.isDeleted.equals(false) &
                  (id == null ? const Constant(true) : table.id.isNotIn([id])),
            ))
            .get();
    final overlaps = existing.any(
      (record) =>
          startTime.isBefore(record.endTime) &&
          endTime.isAfter(record.startTime),
    );
    if (overlaps) {
      throw const FormatException('同一人员同一天的加班时间不能重叠');
    }

    final now = DateTime.now();
    late final int overtimeId;
    await _database.transaction(() async {
      if (id == null) {
        overtimeId = await _database
            .into(_database.overtimeRecords)
            .insert(
              OvertimeRecordsCompanion.insert(
                employeeId: draft.employeeId,
                overtimeDate: overtimeDate,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                overtimeType: Value(_normalizedType(draft.overtimeType)),
                workContent: Value(_nullableText(draft.workContent)),
                workLocation: Value(_nullableText(draft.workLocation)),
                registrant: Value(_nullableText(draft.registrant)),
                remark: Value(_nullableText(draft.remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        overtimeId = id;
        await (_database.update(
          _database.overtimeRecords,
        )..where((table) => table.id.equals(id))).write(
          OvertimeRecordsCompanion(
            overtimeDate: Value(overtimeDate),
            startTime: Value(startTime),
            endTime: Value(endTime),
            durationMinutes: Value(durationMinutes),
            overtimeType: Value(_normalizedType(draft.overtimeType)),
            workContent: Value(_nullableText(draft.workContent)),
            workLocation: Value(_nullableText(draft.workLocation)),
            registrant: Value(_nullableText(draft.registrant)),
            remark: Value(_nullableText(draft.remark)),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }
    });

    return (_database.select(
      _database.overtimeRecords,
    )..where((table) => table.id.equals(overtimeId))).getSingle();
  }

  Future<void> delete(int id) async {
    final record = await findById(id);
    if (record == null) {
      throw StateError('加班记录不存在或已被删除');
    }
    await (_database.update(
      _database.overtimeRecords,
    )..where((table) => table.id.equals(id))).write(
      OvertimeRecordsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  DateTime _normalizeTime(DateTime value, DateTime date) {
    return DateTime(date.year, date.month, date.day, value.hour, value.minute);
  }

  String _normalizedType(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'weekday' : normalized;
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
