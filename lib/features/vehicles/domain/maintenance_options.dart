import '../../../core/database/database_enums.dart';

abstract final class MaintenanceOptions {
  static String unitLabel(MaintenanceIntervalUnit value) => switch (value) {
    MaintenanceIntervalUnit.days => '天',
    MaintenanceIntervalUnit.months => '个月',
    MaintenanceIntervalUnit.years => '年',
  };

  static String statusLabel(MaintenanceDueStatus value) => switch (value) {
    MaintenanceDueStatus.noRecord => '未保养',
    MaintenanceDueStatus.normal => '正常',
    MaintenanceDueStatus.dueSoon => '即将到期',
    MaintenanceDueStatus.due => '已到期',
    MaintenanceDueStatus.overdue => '超期未处理',
  };
}

class MaintenanceTemplateDraft {
  const MaintenanceTemplateDraft({
    required this.name,
    required this.intervalValue,
    required this.intervalUnit,
    this.componentType,
    this.leadDays = 30,
    this.overdueDays = 15,
  });

  final String name;
  final String? componentType;
  final int intervalValue;
  final MaintenanceIntervalUnit intervalUnit;
  final int leadDays;
  final int overdueDays;
}

class VehicleMaintenanceItemDraft {
  const VehicleMaintenanceItemDraft({
    required this.vehicleId,
    required this.name,
    required this.intervalValue,
    required this.intervalUnit,
    this.templateId,
    this.componentType,
    this.leadDays = 30,
    this.overdueDays = 15,
    this.lastServiceDate,
  });

  final int vehicleId;
  final int? templateId;
  final String name;
  final String? componentType;
  final int intervalValue;
  final MaintenanceIntervalUnit intervalUnit;
  final int leadDays;
  final int overdueDays;
  final DateTime? lastServiceDate;
}

class MaintenanceRecordDraft {
  const MaintenanceRecordDraft({
    required this.maintenanceItemId,
    required this.vehicleId,
    required this.serviceDate,
    this.materialCostCents = 0,
    this.laborCostCents = 0,
    this.remark,
  });

  final int maintenanceItemId;
  final int vehicleId;
  final DateTime serviceDate;
  final int materialCostCents;
  final int laborCostCents;
  final String? remark;
}

class LifecycleRecordDraft {
  const LifecycleRecordDraft({
    required this.vehicleId,
    required this.componentType,
    required this.componentKey,
    required this.name,
    required this.installedDate,
    this.thresholdDays,
    this.status = LifecycleStatus.inUse,
    this.remark,
  });

  final int vehicleId;
  final String componentType;
  final String componentKey;
  final String name;
  final DateTime installedDate;
  final int? thresholdDays;
  final LifecycleStatus status;
  final String? remark;
}
