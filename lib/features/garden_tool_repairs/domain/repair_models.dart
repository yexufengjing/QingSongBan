import '../../../core/database/app_database.dart';

String repairMonthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

int repairAmountCents(double quantity, int unitPriceCents) =>
    (quantity * unitPriceCents).round();

enum GardenToolRepairAttachmentType { receipt, before, after, other }

extension GardenToolRepairAttachmentTypeLabel
    on GardenToolRepairAttachmentType {
  String get label => switch (this) {
    GardenToolRepairAttachmentType.receipt => '维修票据',
    GardenToolRepairAttachmentType.before => '维修前照片',
    GardenToolRepairAttachmentType.after => '维修后照片',
    GardenToolRepairAttachmentType.other => '其他凭证',
  };
}

class GardenToolRepairItemDraft {
  const GardenToolRepairItemDraft({
    this.id,
    required this.projectName,
    this.specModel = '',
    required this.countUnit,
    required this.quantity,
    required this.unitPriceCents,
    this.remark = '',
  });

  final int? id;
  final String projectName;
  final String specModel;
  final String countUnit;
  final double quantity;
  final int unitPriceCents;
  final String remark;

  int get amountCents => repairAmountCents(quantity, unitPriceCents);

  factory GardenToolRepairItemDraft.fromRecord(GardenToolRepairItem item) =>
      GardenToolRepairItemDraft(
        id: item.id,
        projectName: item.projectName,
        specModel: item.specModel ?? '',
        countUnit: item.countUnit,
        quantity: item.quantity,
        unitPriceCents: item.unitPriceCents,
        remark: item.remark ?? '',
      );
}

class GardenToolRepairGroupDraft {
  const GardenToolRepairGroupDraft({
    this.id,
    required this.repairMonth,
    required this.repairDate,
    required this.unitId,
    required this.repairerName,
    this.repairerId,
    this.remark = '',
    required this.items,
  });

  final int? id;
  final String repairMonth;
  final DateTime repairDate;
  final int unitId;
  final int? repairerId;
  final String repairerName;
  final String remark;
  final List<GardenToolRepairItemDraft> items;

  int get subtotalCents => items.fold(0, (sum, item) => sum + item.amountCents);
}

class GardenToolRepairLedgerGroup {
  const GardenToolRepairLedgerGroup({
    required this.group,
    required this.items,
    this.attachmentCount = 0,
  });

  final GardenToolRepairGroup group;
  final List<GardenToolRepairItem> items;
  final int attachmentCount;

  int get subtotalCents => items.fold(0, (sum, item) => sum + item.amountCents);

  GardenToolRepairGroupDraft toDraft({DateTime? repairDate}) =>
      GardenToolRepairGroupDraft(
        repairMonth: repairMonthKey(repairDate ?? group.repairDate),
        repairDate: repairDate ?? group.repairDate,
        unitId: group.unitId,
        repairerId: group.repairerId,
        repairerName: group.repairerNameSnapshot,
        remark: group.remark ?? '',
        items: items.map(GardenToolRepairItemDraft.fromRecord).toList(),
      );
}

class GardenToolRepairMonthSummary {
  const GardenToolRepairMonthSummary({
    required this.totalCents,
    required this.groupCount,
    required this.itemCount,
  });

  final int totalCents;
  final int groupCount;
  final int itemCount;

  factory GardenToolRepairMonthSummary.fromGroups(
    Iterable<GardenToolRepairLedgerGroup> groups,
  ) {
    var totalCents = 0;
    var groupCount = 0;
    var itemCount = 0;
    for (final entry in groups) {
      groupCount++;
      itemCount += entry.items.length;
      totalCents += entry.subtotalCents;
    }
    return GardenToolRepairMonthSummary(
      totalCents: totalCents,
      groupCount: groupCount,
      itemCount: itemCount,
    );
  }
}

class GardenToolRepairPricePoint {
  const GardenToolRepairPricePoint({
    required this.repairDate,
    required this.unitName,
    required this.repairerName,
    required this.unitPriceCents,
  });

  final DateTime repairDate;
  final String unitName;
  final String repairerName;
  final int unitPriceCents;
}

class GardenToolRepairPriceItemOption {
  const GardenToolRepairPriceItemOption({
    required this.projectName,
    required this.specModel,
    required this.countUnit,
  });

  final String projectName;
  final String specModel;
  final String countUnit;
}

class GardenToolRepairPriceSummary {
  const GardenToolRepairPriceSummary({
    required this.points,
    required this.averagePriceCents,
    required this.minimumPriceCents,
    required this.maximumPriceCents,
  });

  final List<GardenToolRepairPricePoint> points;
  final int? averagePriceCents;
  final int? minimumPriceCents;
  final int? maximumPriceCents;

  int? get currentPriceCents =>
      points.isEmpty ? null : points.first.unitPriceCents;

  int? get previousPriceCents =>
      points.length < 2 ? null : points[1].unitPriceCents;

  int? get changeCents {
    final current = currentPriceCents;
    final previous = previousPriceCents;
    return current == null || previous == null ? null : current - previous;
  }

  double? get changePercent {
    final current = currentPriceCents;
    final previous = previousPriceCents;
    if (current == null || previous == null || previous == 0) return null;
    return (current - previous) / previous * 100;
  }
}
