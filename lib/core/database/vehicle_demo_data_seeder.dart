import 'package:drift/drift.dart';

import '../../features/vehicles/data/fuel_repository.dart';
import '../../features/vehicles/data/maintenance_repository.dart';
import '../../features/vehicles/data/repair_repository.dart';
import '../../features/vehicles/data/vehicle_condition_repository.dart';
import '../../features/vehicles/data/vehicle_expense_repository.dart';
import '../../features/vehicles/data/vehicle_repository.dart';
import '../../features/vehicles/domain/condition_options.dart';
import '../../features/vehicles/domain/expense_options.dart';
import '../../features/vehicles/domain/fuel_options.dart';
import '../../features/vehicles/domain/maintenance_options.dart';
import '../../features/vehicles/domain/repair_options.dart';
import '../../features/vehicles/domain/vehicle_options.dart';
import 'app_database.dart';
import 'database_enums.dart';

/// Seeds a small, fictional fleet for checking the vehicle screens.
///
/// Run with `--dart-define=QSB_SEED_VEHICLE_DATA=true`. The seed is isolated
/// from employee demo data and can be applied only once per app database.
abstract final class VehicleDemoDataSeeder {
  static const markerKey = 'vehicle_demo_data_seed_v1';

  static Future<bool> seed(AppDatabase database) async {
    final marker = await (database.select(
      database.appSettings,
    )..where((row) => row.settingKey.equals(markerKey))).getSingleOrNull();
    if (marker != null) return false;

    final existing = await VehicleRepository(database)
        .watchVehicles(includeDeleted: true)
        .first;
    if (existing.any((vehicle) => vehicle.vehicleNo.startsWith('DEMO-VH-'))) {
      return false;
    }

    final now = DateTime.now();
    final vehicles = VehicleRepository(database);
    final sweeper = await vehicles.save(
      draft: VehicleDraft(
        name: '一号扫路车',
        vehicleNo: 'DEMO-VH-001',
        licensePlate: '粤A·环卫001',
        vehicleType: VehicleType.sweeper,
        brand: '程力威',
        model: 'CLW5120TSL',
        purchaseDate: DateTime(now.year - 2, 3, 18),
        department: '环卫作业一组',
        workArea: '天河片区',
        responsiblePerson: '李师傅',
        remark: '演示车辆，可用于查看档案、车况和油耗页面。',
      ),
    );
    final waterTruck = await vehicles.save(
      draft: VehicleDraft(
        name: '二号洒水车',
        vehicleNo: 'DEMO-VH-002',
        licensePlate: '粤A·洒水002',
        vehicleType: VehicleType.waterTruck,
        brand: '东风',
        model: 'DFH5160GSS',
        purchaseDate: DateTime(now.year - 1, 7, 6),
        department: '环卫作业二组',
        workArea: '越秀片区',
        responsiblePerson: '王师傅',
        status: VehicleStatus.pendingRepair,
        remark: '演示车辆：存在待处理报修。',
      ),
    );
    await vehicles.save(
      draft: VehicleDraft(
        name: '备用洒水车',
        vehicleNo: 'DEMO-VH-003',
        licensePlate: '粤B·洒水003',
        vehicleType: VehicleType.waterTruck,
        brand: '福田',
        model: '福田小型洒水车',
        purchaseDate: DateTime(now.year - 5, 11, 12),
        department: '机动保障组',
        workArea: '备用车辆',
        responsiblePerson: '陈师傅',
        status: VehicleStatus.stopped,
        remark: '演示车辆：人工停用状态。',
      ),
    );

    final fuel = FuelRepository(database);
    for (var month = 1; month <= now.month; month++) {
      await fuel.save(
        FuelMonthlyDraft(
          vehicleId: sweeper.id,
          year: now.year,
          month: month,
          liters: 480 + month * 13.5,
          amountCents: (480 + month * 13.5).round() * 765,
          workDays: 24,
          workMileage: 1850 + month * 18,
          workHours: 132 + month * 1.5,
          remark: '演示油耗记录',
        ),
      );
      await fuel.save(
        FuelMonthlyDraft(
          vehicleId: waterTruck.id,
          year: now.year,
          month: month,
          liters: month == now.month ? 980 : 610 + month * 11.0,
          amountCents:
              (month == now.month ? 980 : 610 + month * 11.0).round() * 765,
          workDays: 22,
          workMileage: 1450 + month * 15,
          workHours: 118 + month * 1.2,
          remark: month == now.month ? '演示数据：本月用量偏高' : '演示油耗记录',
        ),
      );
    }

    final maintenance = MaintenanceRepository(database);
    await maintenance.seedDefaultItems(sweeper.id);
    await maintenance.seedDefaultItems(waterTruck.id);
    final sweeperItems = await maintenance.watchItems(sweeper.id).first;
    if (sweeperItems.isNotEmpty) {
      await maintenance.record(
        MaintenanceRecordDraft(
          maintenanceItemId: sweeperItems.first.id,
          vehicleId: sweeper.id,
          serviceDate: DateTime(now.year, now.month - 5, 12),
          materialCostCents: 26800,
          laborCostCents: 12000,
          remark: '更换机油并完成例行保养（演示）',
        ),
      );
    }
    final waterItems = await maintenance.watchItems(waterTruck.id).first;
    if (waterItems.isNotEmpty) {
      await maintenance.saveItem(
        VehicleMaintenanceItemDraft(
          vehicleId: waterTruck.id,
          name: '水泵密封检查',
          componentType: 'water',
          intervalValue: 30,
          intervalUnit: MaintenanceIntervalUnit.days,
          lastServiceDate: DateTime(now.year, now.month - 2, now.day),
          leadDays: 7,
        ),
      );
    }

    final conditions = VehicleConditionRepository(database);
    await conditions.save(
      VehicleConditionDraft(
        vehicleId: sweeper.id,
        componentType: 'engine',
        componentKey: 'engineMain',
        status: VehicleConditionStatus.normal,
        observedAt: now,
        detail: '启动正常，运行平稳（演示检查）',
      ),
    );
    await conditions.save(
      VehicleConditionDraft(
        vehicleId: sweeper.id,
        componentType: 'sweeper',
        componentKey: 'brush',
        status: VehicleConditionStatus.minorAbnormal,
        observedAt: now,
        issueTags: const ['brushWear'],
        detail: '右侧扫盘刷毛磨损，建议近期更换。',
      ),
    );
    await conditions.save(
      VehicleConditionDraft(
        vehicleId: waterTruck.id,
        componentType: 'water',
        componentKey: 'waterPump',
        status: VehicleConditionStatus.pendingRepair,
        observedAt: now,
        issueTags: const ['leak'],
        detail: '水泵接口轻微渗漏，等待检修。',
      ),
    );

    final repairs = RepairRepository(database);
    await repairs.save(
      draft: RepairOrderDraft(
        vehicleId: waterTruck.id,
        reportDate: DateTime(now.year, now.month, now.day),
        faultFoundAt: now,
        symptom: '水泵接口渗水，作业压力不足',
        cause: '密封圈老化（演示）',
        project: '水泵接口检修',
        vendor: '广源汽车维修站',
        manager: '周主管',
        reportedAmountCents: 36000,
        ticketStatus: RepairTicketStatus.notIssued,
        status: VehicleRepairStatus.pendingRepair,
        remark: '演示报修单',
      ),
    );
    final completedSweeperRepair = await repairs.save(
      draft: RepairOrderDraft(
        vehicleId: sweeper.id,
        reportDate: DateTime(now.year, now.month - 1, 8),
        faultFoundAt: DateTime(now.year, now.month - 1, 8, 9),
        symptom: '更换右侧扫盘传动皮带',
        cause: '皮带老化开裂（演示）',
        project: '扫盘传动系统维修',
        vendor: '广源汽车维修站',
        manager: '周主管',
        reportedAmountCents: 52000,
        ticketStatus: RepairTicketStatus.issued,
        status: VehicleRepairStatus.completed,
        completedAt: DateTime(now.year, now.month - 1, 9),
        costs: const [
          RepairCostDraft(
            content: '传动皮带',
            quantity: 1,
            unit: '条',
            unitPriceCents: 38000,
            costType: RepairCostType.part,
          ),
          RepairCostDraft(
            content: '拆装工时',
            quantity: 2,
            unit: '小时',
            unitPriceCents: 7000,
            costType: RepairCostType.labor,
          ),
        ],
        remark: '演示已完成维修单',
      ),
    );
    await repairs.updateMarkers(
      id: completedSweeperRepair.id,
      isSettled: true,
      isPaid: true,
    );

    await VehicleExpenseRepository(database).saveManual(
      ManualVehicleExpenseDraft(
        vehicleId: sweeper.id,
        expenseDate: DateTime(now.year, now.month, now.day - 3),
        expenseType: VehicleManualExpenseType.inspection,
        amountCents: 18000,
        remark: '季度安全检测（演示）',
      ),
    );

    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            settingKey: markerKey,
            settingValue: const Value('seeded'),
            updatedAt: Value(now),
          ),
        );
    return true;
  }
}
