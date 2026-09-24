import '../../../core/database/database_enums.dart';

abstract final class VehicleOptions {
  static const vehicleTypes = VehicleType.values;
  static const statuses = VehicleStatus.values;

  static String typeLabel(VehicleType value) => switch (value) {
    VehicleType.sweeper => '环卫清扫车',
    VehicleType.waterTruck => '洒水车',
  };

  /// The shorter labels used by the visual vehicle-management UI.
  static String typeShortLabel(VehicleType value) => switch (value) {
    VehicleType.sweeper => '扫路车',
    VehicleType.waterTruck => '洒水车',
  };

  static String statusLabel(VehicleStatus value) => switch (value) {
    VehicleStatus.normal => '正常',
    VehicleStatus.pendingRepair => '待维修',
    VehicleStatus.repairing => '维修中',
    VehicleStatus.stopped => '停用',
    VehicleStatus.scrapped => '报废',
  };

  static String statusDescription(VehicleStatus value) => switch (value) {
    VehicleStatus.normal => '当前没有登记中的严重问题',
    VehicleStatus.pendingRepair => '存在待处理的报修问题',
    VehicleStatus.repairing => '车辆正在维修处理中',
    VehicleStatus.stopped => '人工停用，不参与日常调度',
    VehicleStatus.scrapped => '车辆已报废，仅保留历史记录',
  };
}

class VehicleDraft {
  const VehicleDraft({
    required this.name,
    required this.vehicleNo,
    required this.vehicleType,
    this.status = VehicleStatus.normal,
    this.licensePlate,
    this.brand,
    this.model,
    this.purchaseDate,
    this.department,
    this.workArea,
    this.responsiblePerson,
    this.remark,
  });

  final String name;
  final String vehicleNo;
  final String? licensePlate;
  final VehicleType vehicleType;
  final String? brand;
  final String? model;
  final DateTime? purchaseDate;
  final String? department;
  final String? workArea;
  final String? responsiblePerson;
  final VehicleStatus status;
  final String? remark;
}
