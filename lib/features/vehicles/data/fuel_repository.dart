import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/fuel_options.dart';
import 'vehicle_scope.dart';

class FuelRepository {
  const FuelRepository(this._database);

  final AppDatabase _database;

  Stream<List<FuelMonthlyRecord>> watchByVehicle(int vehicleId, int year) {
    return (_database.select(_database.fuelMonthlyRecords)
          ..where(
            (table) =>
                table.vehicleId.equals(vehicleId) &
                table.year.equals(year) &
                table.isDeleted.equals(false),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.month)]))
        .watch();
  }

  Future<List<FuelMonthlyRecord>> listByVehicle(int vehicleId, int year) {
    return (_database.select(_database.fuelMonthlyRecords)
          ..where(
            (table) =>
                table.vehicleId.equals(vehicleId) &
                table.year.equals(year) &
                table.isDeleted.equals(false),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.month)]))
        .get();
  }

  Future<List<FuelMonthlyRecord>> listAll(int year) {
    return (_database.select(_database.fuelMonthlyRecords)
          ..where(
            (table) => table.year.equals(year) & table.isDeleted.equals(false),
          )
          ..orderBy([
            (table) => OrderingTerm(expression: table.vehicleId),
            (table) => OrderingTerm(expression: table.month),
          ]))
        .get();
  }

  Future<FuelMonthlyRecord?> findByMonth(
    int vehicleId,
    int year,
    int month, {
    bool includeDeleted = false,
  }) {
    final query = _database.select(_database.fuelMonthlyRecords)
      ..where(
        (table) =>
            table.vehicleId.equals(vehicleId) &
            table.year.equals(year) &
            table.month.equals(month),
      );
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.getSingleOrNull();
  }

  Future<FuelMonthlyRecord> save(FuelMonthlyDraft draft, {int? id}) async {
    if (draft.month < 1 || draft.month > 12) {
      throw ArgumentError('月份必须在 1 到 12 之间');
    }
    if (draft.year < 2000 || draft.year > 2200) {
      throw ArgumentError('年份无效');
    }
    if (draft.liters < 0 || draft.amountCents < 0) {
      throw ArgumentError('油量和油费不能为负数');
    }
    if (draft.workDays != null && draft.workDays! < 0) {
      throw ArgumentError('作业天数不能为负数');
    }
    late final int savedId;
    await _database.transaction(() async {
      await VehicleScope.requireVehicle(_database, draft.vehicleId);
      final duplicate = await findByMonth(
        draft.vehicleId,
        draft.year,
        draft.month,
        includeDeleted: true,
      );
      if (duplicate != null && duplicate.id != id) {
        if (!duplicate.isDeleted) {
          throw StateError('同一车辆同一月份只能有一条油耗记录');
        }
        id = duplicate.id;
      }
      final now = DateTime.now();
      final values = FuelMonthlyRecordsCompanion(
        vehicleId: Value(draft.vehicleId),
        year: Value(draft.year),
        month: Value(draft.month),
        liters: Value(draft.liters),
        amountCents: Value(draft.amountCents),
        workDays: Value(draft.workDays),
        workMileage: Value(draft.workMileage),
        workHours: Value(draft.workHours),
        remark: Value(_nullable(draft.remark)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      );
      if (id == null) {
        savedId = await _database
            .into(_database.fuelMonthlyRecords)
            .insert(
              FuelMonthlyRecordsCompanion.insert(
                vehicleId: draft.vehicleId,
                year: draft.year,
                month: draft.month,
                liters: draft.liters,
                amountCents: draft.amountCents,
                workDays: Value(draft.workDays),
                workMileage: Value(draft.workMileage),
                workHours: Value(draft.workHours),
                remark: Value(_nullable(draft.remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        final updateId = id!;
        savedId = updateId;
        final affected =
            await (_database.update(_database.fuelMonthlyRecords)..where(
                  (table) =>
                      table.id.equals(updateId) &
                      table.vehicleId.equals(draft.vehicleId),
                ))
                .write(values);
        await VehicleScope.requireAffectedRows(
          affected,
          '油耗记录不属于当前车辆或已删除：$updateId',
        );
      }
    });
    return (_database.select(
      _database.fuelMonthlyRecords,
    )..where((table) => table.id.equals(savedId))).getSingle();
  }

  Future<void> softDelete(int vehicleId, int id) async {
    await _database.transaction(() async {
      await VehicleScope.requireVehicle(_database, vehicleId);
      final affected =
          await (_database.update(_database.fuelMonthlyRecords)..where(
                (table) =>
                    table.id.equals(id) &
                    table.vehicleId.equals(vehicleId) &
                    table.isDeleted.equals(false),
              ))
              .write(
                FuelMonthlyRecordsCompanion(
                  isDeleted: const Value(true),
                  updatedAt: Value(DateTime.now()),
                ),
              );
      await VehicleScope.requireAffectedRows(affected, '油耗记录不属于当前车辆或已删除：$id');
    });
  }

  Future<FuelAnnualSummary> annualSummary(int vehicleId, int year) async {
    final rows = await listByVehicle(vehicleId, year);
    if (rows.isEmpty) {
      return FuelAnnualSummary(
        year: year,
        recordedMonths: 0,
        totalLiters: 0,
        totalAmountCents: 0,
        highestLitersMonth: null,
        lowestLitersMonth: null,
        latestMonthChangePercent: null,
      );
    }
    final latest = rows.last;
    final previous = rows.length < 2 ? null : rows[rows.length - 2];
    return FuelAnnualSummary(
      year: year,
      recordedMonths: rows.length,
      totalLiters: rows.fold(0, (sum, row) => sum + row.liters),
      totalAmountCents: rows.fold(0, (sum, row) => sum + row.amountCents),
      highestLitersMonth: rows
          .reduce((a, b) => a.liters >= b.liters ? a : b)
          .month,
      lowestLitersMonth: rows
          .reduce((a, b) => a.liters <= b.liters ? a : b)
          .month,
      latestMonthChangePercent: previous == null || previous.liters == 0
          ? null
          : (latest.liters - previous.liters) / previous.liters * 100,
    );
  }

  String monthLabel(FuelMonthlyRecord row) =>
      AppDateUtils.yearMonth(DateTime(row.year, row.month));

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
