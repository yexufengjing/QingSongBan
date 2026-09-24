import '../../../core/database/database_enums.dart';

abstract final class VehicleConditionOptions {
  static const statuses = VehicleConditionStatus.values;

  static String statusLabel(VehicleConditionStatus value) => switch (value) {
    VehicleConditionStatus.normal => '正常',
    VehicleConditionStatus.minorAbnormal => '轻微异常',
    VehicleConditionStatus.needsAttention => '需要关注',
    VehicleConditionStatus.pendingRepair => '待维修',
    VehicleConditionStatus.repairing => '维修中',
    VehicleConditionStatus.unavailable => '停用/不可用',
  };

  static String statusShortLabel(VehicleConditionStatus value) =>
      switch (value) {
        VehicleConditionStatus.normal => '正常',
        VehicleConditionStatus.minorAbnormal => '轻微异常',
        VehicleConditionStatus.needsAttention => '需关注',
        VehicleConditionStatus.pendingRepair => '待维修',
        VehicleConditionStatus.repairing => '维修中',
        VehicleConditionStatus.unavailable => '不可用',
      };

  static String componentLabel(String value) => switch (value) {
    'engine' => '发动机',
    'light' => '灯光',
    'brake' => '制动',
    'water' => '水路',
    'hydraulic' => '油路/液压',
    'electrical' => '电路',
    'exterior' => '外观与结构',
    'sweeper' => '清扫装置',
    _ => value,
  };
}

class VehicleConditionDraft {
  const VehicleConditionDraft({
    required this.vehicleId,
    required this.componentType,
    required this.componentKey,
    required this.status,
    required this.observedAt,
    this.issueTags = const <String>[],
    this.detail,
  });

  final int vehicleId;
  final String componentType;
  final String componentKey;
  final VehicleConditionStatus status;
  final DateTime observedAt;
  final List<String> issueTags;
  final String? detail;
}
