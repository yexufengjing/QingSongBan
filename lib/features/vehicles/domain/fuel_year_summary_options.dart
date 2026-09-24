import '../../../core/database/app_database.dart';

class FuelYearSummary {
  const FuelYearSummary({
    required this.year,
    required this.vehicles,
    required this.months,
    required this.expectedRecordCount,
    required this.actualRecordCount,
    required this.missingRecords,
    required this.anomalies,
  });

  final int year;
  final List<FuelVehicleSummary> vehicles;
  final List<FuelMonthSummary> months;
  final int expectedRecordCount;
  final int actualRecordCount;
  final List<FuelMissingRecord> missingRecords;
  final List<FuelSummaryAnomaly> anomalies;

  double get totalLiters =>
      months.fold(0, (sum, month) => sum + month.totalLiters);

  int get totalAmountCents =>
      months.fold(0, (sum, month) => sum + month.totalAmountCents);

  double get completenessPercent => expectedRecordCount == 0
      ? 0
      : actualRecordCount / expectedRecordCount * 100;

  int get recordedMonthCount =>
      months.where((month) => month.validVehicleCount > 0).length;

  FuelMonthSummary get currentMonth => months.firstWhere(
    (month) => month.month == DateTime.now().month,
    orElse: () => months.first,
  );
}

class FuelVehicleSummary {
  const FuelVehicleSummary({
    required this.vehicle,
    required this.recordsByMonth,
  });

  final Vehicle vehicle;
  final Map<int, FuelMonthlyRecord?> recordsByMonth;

  int get validMonthCount =>
      recordsByMonth.values.whereType<FuelMonthlyRecord>().length;

  double get totalLiters => recordsByMonth.values
      .whereType<FuelMonthlyRecord>()
      .fold(0, (sum, record) => sum + record.liters);

  int get totalAmountCents => recordsByMonth.values
      .whereType<FuelMonthlyRecord>()
      .fold(0, (sum, record) => sum + record.amountCents);

  double get averageLiters =>
      validMonthCount == 0 ? 0 : totalLiters / validMonthCount;

  int get averageAmountCents =>
      validMonthCount == 0 ? 0 : (totalAmountCents / validMonthCount).round();
}

class FuelMonthSummary {
  const FuelMonthSummary({
    required this.month,
    required this.totalLiters,
    required this.totalAmountCents,
    required this.validVehicleCount,
    required this.averageLiters,
    required this.averageAmountCents,
  });

  final int month;
  final double totalLiters;
  final int totalAmountCents;
  final int validVehicleCount;
  final double averageLiters;
  final int averageAmountCents;
}

class FuelMissingRecord {
  const FuelMissingRecord({
    required this.vehicleId,
    required this.vehicleNo,
    required this.vehicleName,
    required this.month,
  });

  final int vehicleId;
  final String vehicleNo;
  final String vehicleName;
  final int month;

  String get label => '$month月：$vehicleNo $vehicleName';
}

class FuelSummaryAnomaly {
  const FuelSummaryAnomaly({
    required this.vehicleId,
    required this.vehicleName,
    required this.month,
    required this.message,
    required this.changePercent,
  });

  final int vehicleId;
  final String vehicleName;
  final int month;
  final String message;
  final double? changePercent;
}
