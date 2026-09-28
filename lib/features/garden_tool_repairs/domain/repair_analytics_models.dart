class GardenToolRepairUnitAmount {
  const GardenToolRepairUnitAmount({
    required this.unitId,
    required this.unitName,
    required this.totalCents,
    required this.share,
  });

  final int unitId;
  final String unitName;
  final int totalCents;
  final double share;
}

class GardenToolRepairProjectAmount {
  const GardenToolRepairProjectAmount({
    required this.projectName,
    required this.totalCents,
  });

  final String projectName;
  final int totalCents;
}

class GardenToolRepairProjectCount {
  const GardenToolRepairProjectCount({
    required this.projectName,
    required this.count,
  });

  final String projectName;
  final int count;
}

class GardenToolRepairPersonSummary {
  const GardenToolRepairPersonSummary({
    required this.personName,
    required this.unitName,
    required this.itemCount,
    required this.totalCents,
    required this.share,
  });

  final String personName;
  final String unitName;
  final int itemCount;
  final int totalCents;
  final double share;
}

class GardenToolRepairAnalytics {
  const GardenToolRepairAnalytics({
    required this.totalCents,
    required this.itemCount,
    required this.averageMonthCents,
    required this.repairerCount,
    required this.monthlyTotalsCents,
    required this.unitAmounts,
    required this.projectAmounts,
    required this.projectCounts,
    required this.repairers,
  });

  final int totalCents;
  final int itemCount;
  final int averageMonthCents;
  final int repairerCount;
  final List<int> monthlyTotalsCents;
  final List<GardenToolRepairUnitAmount> unitAmounts;
  final List<GardenToolRepairProjectAmount> projectAmounts;
  final List<GardenToolRepairProjectCount> projectCounts;
  final List<GardenToolRepairPersonSummary> repairers;
}
