import '../../../core/database/database_enums.dart';

abstract final class TireOptions {
  static const positions = TirePosition.values;

  static String positionLabel(TirePosition value) => switch (value) {
    TirePosition.leftFront => '左前轮 LF',
    TirePosition.rightFront => '右前轮 RF',
    TirePosition.leftRearOuter => '左后轮外侧 LRO',
    TirePosition.leftRearInner => '左后轮内侧 LRI',
    TirePosition.rightRearOuter => '右后轮外侧 RRO',
    TirePosition.rightRearInner => '右后轮内侧 RRI',
  };

  static String positionCode(TirePosition value) => switch (value) {
    TirePosition.leftFront => 'leftFront',
    TirePosition.rightFront => 'rightFront',
    TirePosition.leftRearOuter => 'leftRearOuter',
    TirePosition.leftRearInner => 'leftRearInner',
    TirePosition.rightRearOuter => 'rightRearOuter',
    TirePosition.rightRearInner => 'rightRearInner',
  };

  static String conditionLabel(TireCondition value) => switch (value) {
    TireCondition.newTire => '新胎',
    TireCondition.usedTire => '旧胎',
    TireCondition.retreaded => '翻新胎',
  };

  static String statusLabel(TireAssetStatus value) => switch (value) {
    TireAssetStatus.inUse => '使用中',
    TireAssetStatus.spare => '备用',
    TireAssetStatus.removed => '已拆下',
    TireAssetStatus.scrapped => '报废',
  };

  static String wearLabel(TireWearLevel value) => switch (value) {
    TireWearLevel.good => '良好',
    TireWearLevel.light => '轻度磨损',
    TireWearLevel.medium => '中度磨损',
    TireWearLevel.severe => '严重磨损',
    TireWearLevel.replaceRecommended => '建议更换',
  };

  static String installReasonLabel(TireInstallReason value) => switch (value) {
    TireInstallReason.newReplacement => '新轮胎更换',
    TireInstallReason.rotation => '正常轮换',
    TireInstallReason.relocation => '倒胎',
    TireInstallReason.reinstalledAfterRepair => '修补后复装',
    TireInstallReason.temporaryRepair => '维修临时调整',
    TireInstallReason.other => '其他',
  };
}

class TireDraft {
  const TireDraft({
    required this.tireNo,
    this.brand,
    this.specification,
    this.condition = TireCondition.newTire,
    this.firstUseDate,
    this.status = TireAssetStatus.spare,
    this.wearLevel = TireWearLevel.good,
    this.remark,
  });

  final String tireNo;
  final String? brand;
  final String? specification;
  final TireCondition condition;
  final DateTime? firstUseDate;
  final TireAssetStatus status;
  final TireWearLevel wearLevel;
  final String? remark;
}
