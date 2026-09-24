class FuelMonthlyDraft {
  const FuelMonthlyDraft({
    required this.vehicleId,
    required this.year,
    required this.month,
    required this.liters,
    required this.amountCents,
    this.workDays,
    this.workMileage,
    this.workHours,
    this.remark,
  });

  final int vehicleId;
  final int year;
  final int month;
  final double liters;
  final int amountCents;
  final int? workDays;
  final double? workMileage;
  final double? workHours;
  final String? remark;
}

class FuelAnnualSummary {
  const FuelAnnualSummary({
    required this.year,
    required this.recordedMonths,
    required this.totalLiters,
    required this.totalAmountCents,
    required this.highestLitersMonth,
    required this.lowestLitersMonth,
    required this.latestMonthChangePercent,
  });

  final int year;
  final int recordedMonths;
  final double totalLiters;
  final int totalAmountCents;
  final int? highestLitersMonth;
  final int? lowestLitersMonth;
  final double? latestMonthChangePercent;

  double get averageLiters =>
      recordedMonths == 0 ? 0 : totalLiters / recordedMonths;

  int get averageAmountCents =>
      recordedMonths == 0 ? 0 : (totalAmountCents / recordedMonths).round();
}
