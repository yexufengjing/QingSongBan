import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/expense_options.dart';
import 'vehicle_scope.dart';

class VehicleExpenseRepository {
  const VehicleExpenseRepository(this._database);

  final AppDatabase _database;

  Future<ManualVehicleExpense> saveManual(
    ManualVehicleExpenseDraft draft, {
    int? id,
  }) async {
    if (draft.amountCents < 0) throw ArgumentError('费用不能为负数');
    final now = DateTime.now();
    final values = ManualVehicleExpensesCompanion(
      vehicleId: Value(draft.vehicleId),
      expenseDate: Value(AppDateUtils.dateOnly(draft.expenseDate)),
      expenseType: Value(draft.expenseType.name),
      amountCents: Value(draft.amountCents),
      remark: Value(_nullable(draft.remark)),
      updatedAt: Value(now),
      isDeleted: const Value(false),
    );
    late final int savedId;
    await _database.transaction(() async {
      await VehicleScope.requireVehicle(_database, draft.vehicleId);
      if (id == null) {
        savedId = await _database
            .into(_database.manualVehicleExpenses)
            .insert(
              ManualVehicleExpensesCompanion.insert(
                vehicleId: draft.vehicleId,
                expenseDate: AppDateUtils.dateOnly(draft.expenseDate),
                expenseType: draft.expenseType.name,
                amountCents: draft.amountCents,
                remark: Value(_nullable(draft.remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        savedId = id;
        final affected =
            await (_database.update(_database.manualVehicleExpenses)..where(
                  (table) =>
                      table.id.equals(id) &
                      table.vehicleId.equals(draft.vehicleId) &
                      table.isDeleted.equals(false),
                ))
                .write(values);
        await VehicleScope.requireAffectedRows(affected, '费用记录不属于当前车辆或已删除：$id');
      }
    });
    return (_database.select(
      _database.manualVehicleExpenses,
    )..where((table) => table.id.equals(savedId))).getSingle();
  }

  Future<List<VehicleExpenseItem>> list(int vehicleId, {int? year}) async {
    final expenses =
        await (_database.select(_database.manualVehicleExpenses)
              ..where(
                (table) =>
                    table.vehicleId.equals(vehicleId) &
                    table.isDeleted.equals(false),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.expenseDate),
              ]))
            .get();
    final fuels =
        await (_database.select(_database.fuelMonthlyRecords)..where(
              (table) =>
                  table.vehicleId.equals(vehicleId) &
                  table.isDeleted.equals(false),
            ))
            .get();
    final repairs =
        await (_database.select(_database.repairOrders)..where(
              (table) =>
                  table.vehicleId.equals(vehicleId) &
                  table.status.equalsValue(VehicleRepairStatus.completed) &
                  table.isDeleted.equals(false),
            ))
            .get();
    final maintenance =
        await (_database.select(_database.maintenanceRecords)..where(
              (table) =>
                  table.vehicleId.equals(vehicleId) &
                  table.isDeleted.equals(false),
            ))
            .get();
    final result = <VehicleExpenseItem>[
      ...expenses
          .where((item) => year == null || item.expenseDate.year == year)
          .map(
            (item) => VehicleExpenseItem(
              vehicleId: vehicleId,
              date: item.expenseDate,
              sourceType: 'manual',
              sourceId: item.id,
              category: '其他费用',
              subCategory: item.expenseType,
              amountCents: item.amountCents,
              description: item.remark ?? '其他费用',
            ),
          ),
      ...fuels
          .where((item) => year == null || item.year == year)
          .map(
            (item) => VehicleExpenseItem(
              vehicleId: vehicleId,
              date: DateTime(item.year, item.month),
              sourceType: 'fuel',
              sourceId: item.id,
              category: '油耗费用',
              subCategory: null,
              amountCents: item.amountCents,
              description: '${item.year}-${item.month}月油耗 ${item.liters}L',
            ),
          ),
      ...repairs
          .where((item) => year == null || item.reportDate.year == year)
          .map(
            (item) => VehicleExpenseItem(
              vehicleId: vehicleId,
              date: item.completedAt ?? item.reportDate,
              sourceType: 'repair',
              sourceId: item.id,
              category: '维修费用',
              subCategory: '备件及工时',
              amountCents: item.actualAmountCents,
              description: item.symptom,
            ),
          ),
      ...maintenance
          .where((item) => year == null || item.serviceDate.year == year)
          .map(
            (item) => VehicleExpenseItem(
              vehicleId: vehicleId,
              date: item.serviceDate,
              sourceType: 'maintenance',
              sourceId: item.id,
              category: '保养费用',
              subCategory: null,
              amountCents: item.totalCostCents,
              description: item.remark ?? '保养执行',
            ),
          ),
    ];
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
