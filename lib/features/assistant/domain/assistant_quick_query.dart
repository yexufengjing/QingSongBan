/// A saved, deterministic scope for a common assistant query.
enum AssistantQuickQueryKind {
  attendance,
  payroll,
  inventoryLowStock,
  purchasePending,
  distribution,
  vehicleRepair,
}

class AssistantQuickQuery {
  const AssistantQuickQuery({
    required this.kind,
    this.yearMonth,
    this.employeeId,
    this.vehicleId,
  });

  final AssistantQuickQueryKind kind;
  final String? yearMonth;
  final int? employeeId;
  final int? vehicleId;

  String get label => switch (kind) {
    AssistantQuickQueryKind.attendance => '考勤',
    AssistantQuickQueryKind.payroll => '工资',
    AssistantQuickQueryKind.inventoryLowStock => '库存低库存',
    AssistantQuickQueryKind.purchasePending => '采购待处理',
    AssistantQuickQueryKind.distribution => '福利领取',
    AssistantQuickQueryKind.vehicleRepair => '车辆维修',
  };

  /// Stable display text suitable for a shortcut button or favorite.
  String get title {
    final month = yearMonth == null ? '' : ' · $yearMonth';
    return switch (kind) {
      AssistantQuickQueryKind.attendance => '查询考勤$month',
      AssistantQuickQueryKind.payroll => '查询工资$month',
      AssistantQuickQueryKind.inventoryLowStock => '查看库存低库存',
      AssistantQuickQueryKind.purchasePending => '查看采购待处理',
      AssistantQuickQueryKind.distribution => '查看福利领取$month',
      AssistantQuickQueryKind.vehicleRepair => '查看车辆维修$month',
    };
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'yearMonth': yearMonth,
    'employeeId': employeeId,
    'vehicleId': vehicleId,
  };

  factory AssistantQuickQuery.fromJson(Map<String, Object?> json) {
    final kindName = json['kind'];
    final kind = AssistantQuickQueryKind.values
        .where((value) => value.name == kindName)
        .firstOrNull;
    if (kind == null) {
      throw FormatException('Unknown assistant quick query kind: $kindName');
    }
    return AssistantQuickQuery(
      kind: kind,
      yearMonth: json['yearMonth'] as String?,
      employeeId: (json['employeeId'] as num?)?.toInt(),
      vehicleId: (json['vehicleId'] as num?)?.toInt(),
    );
  }
}

extension on Iterable<AssistantQuickQueryKind> {
  AssistantQuickQueryKind? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
