enum DistributionCategory { welfare, office, tool }

enum DistributionStatus { notReceived, received }

class DistributionEntry {
  const DistributionEntry({
    required this.id,
    required this.batchId,
    required this.recipientType,
    required this.recipientKey,
    required this.recipientName,
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.status,
    this.employeeId,
    this.employmentType,
    this.welfarePosition,
    this.signedAt,
    this.createdAt,
    this.actualDistributionMonth,
    this.standardQuantity,
    this.note,
  });

  final int id;
  final int batchId;
  final String recipientType;
  final String recipientKey;
  final int? employeeId;
  final String recipientName;
  final String? employmentType;
  final String? welfarePosition;
  final String itemCode;
  final String itemName;
  final double quantity;
  final String unit;
  final DistributionStatus status;
  final DateTime? signedAt;
  final DateTime? createdAt;
  final String? actualDistributionMonth;
  final double? standardQuantity;
  final String? note;
}

class DistributionRecipientGroup {
  const DistributionRecipientGroup({
    required this.recipientKey,
    required this.recipientName,
    required this.recipientType,
    required this.entries,
    this.employeeId,
    this.employmentType,
    this.welfarePosition,
  });

  final String recipientKey;
  final String recipientName;
  final String recipientType;
  final int? employeeId;
  final String? employmentType;
  final String? welfarePosition;
  final List<DistributionEntry> entries;

  bool get allReceived =>
      entries.isNotEmpty &&
      entries.every((e) => e.status == DistributionStatus.received);
  bool get hasNotReceived =>
      entries.any((e) => e.status == DistributionStatus.notReceived);
  bool get hasPending => hasNotReceived;
}

class DistributionSummary {
  const DistributionSummary({
    required this.recipientCount,
    required this.receivedCount,
    required this.notReceivedCount,
    required this.entryReceivedCount,
    required this.entryNotReceivedCount,
  });

  final int recipientCount;
  final int receivedCount;
  final int notReceivedCount;
  final int entryReceivedCount;
  final int entryNotReceivedCount;

  int get pendingCount => notReceivedCount;
}

class WelfareCandidate {
  const WelfareCandidate({
    required this.id,
    required this.name,
    required this.employeeNo,
    required this.employmentType,
    required this.isCurrentlyActive,
  });

  final int id;
  final String name;
  final String employeeNo;
  final String employmentType;
  final bool isCurrentlyActive;
}

class ManualDistributionDraft {
  const ManualDistributionDraft({
    required this.category,
    required this.month,
    required this.recipientName,
    required this.recipientType,
    required this.recipientKey,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.employeeId,
    this.note,
  });

  final DistributionCategory category;
  final String month;
  final String recipientName;
  final String recipientType;
  final String recipientKey;
  final int? employeeId;
  final String itemName;
  final double quantity;
  final String unit;
  final String? note;
}
