import '../../../core/database/database_enums.dart';

abstract final class RepairOptions {
  static String statusLabel(VehicleRepairStatus value) => switch (value) {
    VehicleRepairStatus.reported => '已报修',
    VehicleRepairStatus.pendingRepair => '待维修',
    VehicleRepairStatus.repairing => '维修中',
    VehicleRepairStatus.completed => '已完成',
    VehicleRepairStatus.cancelled => '已取消',
  };

  static String costTypeLabel(RepairCostType value) => switch (value) {
    RepairCostType.labor => '工时费',
    RepairCostType.part => '备件',
    RepairCostType.material => '材料',
    RepairCostType.outsourcing => '外协',
    RepairCostType.other => '其他',
  };

  static String ticketStatusLabel(RepairTicketStatus value) => switch (value) {
    RepairTicketStatus.notIssued => '未开',
    RepairTicketStatus.issued => '已开',
    RepairTicketStatus.notRequired => '不需要',
  };
}

class RepairCostDraft {
  const RepairCostDraft({
    required this.content,
    required this.quantity,
    required this.unit,
    required this.unitPriceCents,
    required this.costType,
  });

  final String content;
  final double quantity;
  final String unit;
  final int unitPriceCents;
  final RepairCostType costType;

  int get subtotalCents => (quantity * unitPriceCents).round();
}

class RepairPartDraft {
  const RepairPartDraft({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.amountCents,
    this.costItemIndex,
    this.tireId,
    this.componentType,
    this.remark,
  });

  final String name;
  final double quantity;
  final String unit;
  final int amountCents;
  final int? costItemIndex;
  final int? tireId;
  final String? componentType;
  final String? remark;
}

class RepairOrderDraft {
  const RepairOrderDraft({
    required this.vehicleId,
    required this.reportDate,
    required this.faultFoundAt,
    required this.symptom,
    required this.ticketStatus,
    this.cause,
    this.project,
    this.departAt,
    this.vendor,
    this.manager,
    this.reportedAmountCents = 0,
    this.status = VehicleRepairStatus.reported,
    this.completedAt,
    this.remark,
    this.costs = const <RepairCostDraft>[],
    this.parts = const <RepairPartDraft>[],
  });

  final int vehicleId;
  final DateTime reportDate;
  final DateTime faultFoundAt;
  final String symptom;
  final String? cause;
  final String? project;
  final DateTime? departAt;
  final String? vendor;
  final String? manager;
  final int reportedAmountCents;
  final RepairTicketStatus ticketStatus;
  final VehicleRepairStatus status;
  final DateTime? completedAt;
  final String? remark;
  final List<RepairCostDraft> costs;
  final List<RepairPartDraft> parts;
}
