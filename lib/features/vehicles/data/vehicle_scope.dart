import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

abstract final class VehicleScope {
  static Future<Vehicle> requireVehicle(
    AppDatabase database,
    int vehicleId,
  ) async {
    final vehicle =
        await (database.select(database.vehicles)..where(
              (table) =>
                  table.id.equals(vehicleId) & table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (vehicle == null) throw StateError('车辆不存在或已删除：$vehicleId');
    return vehicle;
  }

  static Future<RepairOrder> requireRepairForVehicle(
    AppDatabase database, {
    required int repairOrderId,
    required int vehicleId,
  }) async {
    final order =
        await (database.select(database.repairOrders)..where(
              (table) =>
                  table.id.equals(repairOrderId) &
                  table.vehicleId.equals(vehicleId) &
                  table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (order == null) {
      throw StateError('维修单不属于当前车辆或已删除：$repairOrderId');
    }
    return order;
  }

  static Future<void> requireAffectedRows(int count, String message) async {
    if (count != 1) throw StateError(message);
  }
}
