import '../../../core/database/database_enums.dart';

class ManualVehicleExpenseDraft {
  const ManualVehicleExpenseDraft({
    required this.vehicleId,
    required this.expenseDate,
    required this.expenseType,
    required this.amountCents,
    this.remark,
  });

  final int vehicleId;
  final DateTime expenseDate;
  final VehicleManualExpenseType expenseType;
  final int amountCents;
  final String? remark;
}

class VehicleExpenseItem {
  const VehicleExpenseItem({
    required this.vehicleId,
    required this.date,
    required this.sourceType,
    required this.sourceId,
    required this.category,
    required this.subCategory,
    required this.amountCents,
    required this.description,
  });

  final int vehicleId;
  final DateTime date;
  final String sourceType;
  final int sourceId;
  final String category;
  final String? subCategory;
  final int amountCents;
  final String description;
}

abstract final class VehicleExpenseOptions {
  static String manualTypeLabel(VehicleManualExpenseType type) =>
      switch (type) {
        VehicleManualExpenseType.inspection => '年检',
        VehicleManualExpenseType.outsourcing => '临时外协',
        VehicleManualExpenseType.cleaning => '清洗',
        VehicleManualExpenseType.painting => '喷漆防腐',
        VehicleManualExpenseType.other => '其他',
      };
}
