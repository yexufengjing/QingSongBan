import '../domain/repair_analytics_models.dart';
import '../domain/repair_models.dart';

class GardenToolRepairAnalysisService {
  const GardenToolRepairAnalysisService();

  GardenToolRepairAnalytics summarize(
    Iterable<GardenToolRepairLedgerGroup> source, {
    required int year,
    int? month,
  }) {
    final groups = source.where((entry) {
      final date = entry.group.repairDate;
      return date.year == year && (month == null || date.month == month);
    });
    final monthlyTotals = List<int>.filled(12, 0);
    final unitTotals = <int, int>{};
    final unitNames = <int, String>{};
    final projectTotals = <String, int>{};
    final projectCounts = <String, int>{};
    final personItems = <String, int>{};
    final personTotals = <String, int>{};
    final personNames = <String, (String, String)>{};
    var totalCents = 0;
    var itemCount = 0;

    for (final entry in groups) {
      final unitName = entry.group.unitNameSnapshot;
      final unitId = entry.group.unitId;
      final personName = entry.group.repairerNameSnapshot;
      unitNames[unitId] = unitName;
      for (final item in entry.items) {
        totalCents += item.amountCents;
        monthlyTotals[entry.group.repairDate.month - 1] += item.amountCents;
        unitTotals.update(
          unitId,
          (value) => value + item.amountCents,
          ifAbsent: () => item.amountCents,
        );
        projectTotals.update(
          item.projectName,
          (value) => value + item.amountCents,
          ifAbsent: () => item.amountCents,
        );
        projectCounts.update(
          item.projectName,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final personKey = '$unitName\u0000$personName';
        personNames[personKey] = (unitName, personName);
        personItems.update(personKey, (value) => value + 1, ifAbsent: () => 1);
        personTotals.update(
          personKey,
          (value) => value + item.amountCents,
          ifAbsent: () => item.amountCents,
        );
        itemCount++;
      }
    }

    double shareOf(int amount) => totalCents == 0 ? 0.0 : amount / totalCents;
    final unitAmounts =
        unitTotals.entries
            .map(
              (entry) => GardenToolRepairUnitAmount(
                unitId: entry.key,
                unitName: unitNames[entry.key] ?? '',
                totalCents: entry.value,
                share: shareOf(entry.value),
              ),
            )
            .toList()
          ..sort((a, b) => b.totalCents.compareTo(a.totalCents));
    final projectAmounts =
        projectTotals.entries
            .map(
              (entry) => GardenToolRepairProjectAmount(
                projectName: entry.key,
                totalCents: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalCents.compareTo(a.totalCents));
    final projectFrequency =
        projectCounts.entries
            .map(
              (entry) => GardenToolRepairProjectCount(
                projectName: entry.key,
                count: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    final repairers =
        personNames.entries.map((entry) {
          final key = entry.key;
          final (unitName, personName) = entry.value;
          final amount = personTotals[key] ?? 0;
          return GardenToolRepairPersonSummary(
            personName: personName,
            unitName: unitName,
            itemCount: personItems[key] ?? 0,
            totalCents: amount,
            share: shareOf(amount),
          );
        }).toList()..sort((a, b) {
          final byUnit = a.unitName.compareTo(b.unitName);
          return byUnit != 0 ? byUnit : a.personName.compareTo(b.personName);
        });

    return GardenToolRepairAnalytics(
      totalCents: totalCents,
      itemCount: itemCount,
      averageMonthCents: month == null ? (totalCents / 12).round() : totalCents,
      repairerCount: repairers.length,
      monthlyTotalsCents: monthlyTotals,
      unitAmounts: unitAmounts,
      projectAmounts: projectAmounts,
      projectCounts: projectFrequency,
      repairers: repairers,
    );
  }
}
