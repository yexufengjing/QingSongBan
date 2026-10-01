import 'purchase_status.dart';

class PurchaseItemDraft {
  const PurchaseItemDraft({
    this.inventoryMaterialId,
    required this.itemName,
    this.specification,
    required this.unit,
    this.currentStockSnapshot,
    required this.requestQuantity,
    this.remark,
  });

  final int? inventoryMaterialId;
  final String itemName;
  final String? specification;
  final String unit;
  final double? currentStockSnapshot;
  final double requestQuantity;
  final String? remark;
}

class CreatePurchaseRequestInput {
  const CreatePurchaseRequestInput({
    required this.title,
    required this.items,
    this.requestDate,
    this.demandReason,
    this.remark,
  });

  final String title;
  final List<PurchaseItemDraft> items;
  final DateTime? requestDate;
  final String? demandReason;
  final String? remark;
}

class UpdatePurchaseRequestInput {
  const UpdatePurchaseRequestInput({
    required this.title,
    required this.items,
    this.requestDate,
    this.appliedDate,
    this.oaRequestNo,
    this.oaTitle,
    this.oaUrl,
    this.purchaseDepartment,
    this.purchaserName,
    this.assignedDate,
    this.arrivalNoticeDate,
    this.receiveLocation,
    this.demandReason,
    this.remark,
  });

  final String title;
  final List<PurchaseItemDraft> items;
  final DateTime? requestDate;
  final DateTime? appliedDate;
  final String? oaRequestNo;
  final String? oaTitle;
  final String? oaUrl;
  final String? purchaseDepartment;
  final String? purchaserName;
  final DateTime? assignedDate;
  final DateTime? arrivalNoticeDate;
  final String? receiveLocation;
  final String? demandReason;
  final String? remark;
}

/// Full metadata snapshot for edits that must not implicitly change status.
/// Reuse the complete PurchaseRequestDetail values when clearing fields.
class UpdatePurchaseMetadataInput {
  const UpdatePurchaseMetadataInput({
    required this.title,
    this.requestDate,
    this.appliedDate,
    this.oaRequestNo,
    this.oaTitle,
    this.oaUrl,
    this.purchaseDepartment,
    this.purchaserName,
    this.assignedDate,
    this.arrivalNoticeDate,
    this.receiveLocation,
    this.demandReason,
    this.remark,
  });

  final String title;
  final DateTime? requestDate;
  final DateTime? appliedDate;
  final String? oaRequestNo;
  final String? oaTitle;
  final String? oaUrl;
  final String? purchaseDepartment;
  final String? purchaserName;
  final DateTime? assignedDate;
  final DateTime? arrivalNoticeDate;
  final String? receiveLocation;
  final String? demandReason;
  final String? remark;
}

class ConfirmAppliedInput {
  const ConfirmAppliedInput({
    required this.appliedDate,
    this.oaRequestNo,
    this.oaTitle,
    this.oaUrl,
  });

  final DateTime appliedDate;
  final String? oaRequestNo;
  final String? oaTitle;
  final String? oaUrl;
}

class AssignPurchaserInput {
  const AssignPurchaserInput({
    this.purchaseDepartment,
    this.purchaserName,
    required this.assignedDate,
  });

  final String? purchaseDepartment;
  final String? purchaserName;
  final DateTime assignedDate;
}

class PendingReceiveInput {
  const PendingReceiveInput({
    required this.arrivalNoticeDate,
    this.receiveLocation,
  });

  final DateTime arrivalNoticeDate;
  final String? receiveLocation;
}

class PurchaseStockInLineInput {
  const PurchaseStockInLineInput({
    required this.requestItemId,
    required this.quantity,
    this.confirmExcess = false,
    this.inventoryMaterialId,
    this.createInventoryMaterial = false,
    this.restoreLinkedMaterial = false,
    this.newMaterialCode,
    this.storageLocation,
    this.remark,
  });

  final int requestItemId;
  final double quantity;
  final bool confirmExcess;

  /// Set when restoring a disabled linked material or selecting a replacement.
  final int? inventoryMaterialId;

  /// Creates a new active stock material when no active replacement exists.
  final bool createInventoryMaterial;

  /// Confirms reactivating the currently linked inactive inventory material.
  final bool restoreLinkedMaterial;
  final String? newMaterialCode;
  final String? storageLocation;
  final String? remark;
}

class StockInInput {
  const StockInInput({
    required this.requestId,
    required this.stockInDate,
    required this.lines,
    this.confirmedNonPending = false,
    this.remark,
  });

  final int requestId;
  final DateTime stockInDate;
  final List<PurchaseStockInLineInput> lines;

  /// Required when entering stock-in from a status other than pending receive.
  final bool confirmedNonPending;
  final String? remark;
}

class ManualPurchaseStatusInput {
  const ManualPurchaseStatusInput({
    required this.requestId,
    required this.targetStatus,
    required this.confirmed,
    this.remark,
  });

  final int requestId;
  final PurchaseStatus targetStatus;

  /// UI sets this only after the user confirms a non-normal status jump.
  final bool confirmed;
  final String? remark;
}

class PurchaseRequestSummary {
  const PurchaseRequestSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.requestDate,
    required this.itemCount,
    required this.itemNames,
    this.items = const [],
    this.appliedDate,
    this.purchaserName,
    this.assignedDate,
    this.arrivalNoticeDate,
    this.receiveLocation,
    this.hasReminder = false,
  });

  final int id;
  final String title;
  final PurchaseStatus status;
  final DateTime? requestDate;
  final int itemCount;
  final List<String> itemNames;
  final List<PurchaseRequestItemView> items;
  final DateTime? appliedDate;
  final String? purchaserName;
  final DateTime? assignedDate;
  final DateTime? arrivalNoticeDate;
  final String? receiveLocation;
  final bool hasReminder;
}

class PurchaseRequestDetail {
  const PurchaseRequestDetail({
    required this.summary,
    required this.items,
    required this.statusLogs,
    required this.stockEntries,
    this.oaRequestNo,
    this.oaTitle,
    this.oaUrl,
    this.purchaseDepartment,
    this.demandReason,
    this.remark,
    this.completedAt,
  });

  final PurchaseRequestSummary summary;
  final List<PurchaseRequestItemView> items;
  final List<PurchaseStatusLogView> statusLogs;
  final List<PurchaseStockEntryView> stockEntries;
  final String? oaRequestNo;
  final String? oaTitle;
  final String? oaUrl;
  final String? purchaseDepartment;
  final String? demandReason;
  final String? remark;
  final DateTime? completedAt;
}

class PurchaseRequestItemView {
  const PurchaseRequestItemView({
    required this.id,
    required this.itemName,
    required this.unit,
    required this.requestQuantity,
    required this.receivedQuantity,
    required this.remainingQuantity,
    this.inventoryMaterialId,
    this.specification,
    this.currentStockSnapshot,
    this.remark,
  });

  final int id;
  final int? inventoryMaterialId;
  final String itemName;
  final String? specification;
  final String unit;
  final double? currentStockSnapshot;
  final double requestQuantity;
  final double receivedQuantity;
  final double remainingQuantity;
  final String? remark;
}

class PurchaseStatusLogView {
  const PurchaseStatusLogView({
    required this.id,
    required this.changedAt,
    required this.newStatus,
    this.oldStatus,
    this.remark,
  });

  final int id;
  final DateTime changedAt;
  final PurchaseStatus? oldStatus;
  final PurchaseStatus newStatus;
  final String? remark;
}

class PurchaseStockEntryView {
  const PurchaseStockEntryView({
    required this.id,
    required this.requestItemId,
    required this.inventoryMaterialId,
    required this.inventoryReceiptId,
    required this.quantity,
    required this.stockInDate,
    this.inventoryTransactionId,
    this.storageLocation,
    this.remark,
    this.isReversed = false,
    this.reversedAt,
  });

  final int id;
  final int requestItemId;
  final int inventoryMaterialId;
  final int inventoryReceiptId;
  final int? inventoryTransactionId;
  final double quantity;
  final DateTime stockInDate;
  final String? storageLocation;
  final String? remark;
  final bool isReversed;
  final DateTime? reversedAt;
}

class PurchaseFilter {
  const PurchaseFilter({
    this.statuses = const {},
    this.keyword = '',
    this.startDate,
    this.endDate,
    this.purchaserName,
    this.inventoryMaterialId,
    this.demandReason,
    this.historyStatus = const {},
  });

  final Set<PurchaseStatus> statuses;
  final String keyword;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? purchaserName;
  final int? inventoryMaterialId;
  final String? demandReason;
  final Set<PurchaseStatus> historyStatus;

  PurchaseFilter copyWith({
    Set<PurchaseStatus>? statuses,
    String? keyword,
    DateTime? startDate,
    DateTime? endDate,
    String? purchaserName,
    int? inventoryMaterialId,
    String? demandReason,
    bool clearDates = false,
    bool clearPurchaser = false,
    bool clearMaterial = false,
    bool clearDemandReason = false,
    Set<PurchaseStatus>? historyStatus,
  }) => PurchaseFilter(
    statuses: statuses ?? this.statuses,
    keyword: keyword ?? this.keyword,
    startDate: clearDates ? null : startDate ?? this.startDate,
    endDate: clearDates ? null : endDate ?? this.endDate,
    purchaserName: clearPurchaser ? null : purchaserName ?? this.purchaserName,
    inventoryMaterialId: clearMaterial
        ? null
        : inventoryMaterialId ?? this.inventoryMaterialId,
    demandReason: clearDemandReason ? null : demandReason ?? this.demandReason,
    historyStatus: historyStatus ?? this.historyStatus,
  );
}

class PurchaseHistoryFilter extends PurchaseFilter {
  const PurchaseHistoryFilter({
    super.keyword,
    super.startDate,
    super.endDate,
    super.purchaserName,
    super.inventoryMaterialId,
    super.historyStatus = const {},
    this.mode = PurchaseHistoryMode.byRequest,
  });

  final PurchaseHistoryMode mode;
}

enum PurchaseHistoryMode { byRequest, byMaterial }

class PurchaseHistoryRow {
  const PurchaseHistoryRow({
    required this.requestId,
    required this.requestItemId,
    this.inventoryMaterialId,
    required this.itemName,
    required this.unit,
    required this.requestQuantity,
    required this.receivedQuantity,
    required this.requestDate,
    required this.status,
    this.specification,
    this.appliedDate,
    this.lastStockInDate,
    this.purchaserName,
    this.completedAt,
    this.cycleDays,
    this.currentStock,
  });

  final int requestId;
  final int requestItemId;
  final int? inventoryMaterialId;
  final String itemName;
  final String? specification;
  final String unit;
  final double requestQuantity;
  final double receivedQuantity;
  final DateTime? requestDate;
  final DateTime? appliedDate;
  final DateTime? lastStockInDate;
  final String? purchaserName;
  final PurchaseStatus status;
  final DateTime? completedAt;
  final int? cycleDays;
  final double? currentStock;
}

class PurchaseItemHistory {
  const PurchaseItemHistory({
    required this.inventoryMaterialId,
    required this.itemName,
    required this.unit,
    required this.rows,
    this.specification,
    this.currentStock,
    this.mostRecentRequestDate,
    this.mostRecentStockInDate,
    this.recentCycleDays = const [],
    this.averageCycleDays,
  });

  final int inventoryMaterialId;
  final String itemName;
  final String? specification;
  final String unit;
  final double? currentStock;
  final DateTime? mostRecentRequestDate;
  final DateTime? mostRecentStockInDate;
  final List<PurchaseHistoryRow> rows;
  final List<int> recentCycleDays;
  final double? averageCycleDays;
  int get purchaseCount => rows.map((row) => row.requestId).toSet().length;
}

class PurchaseDashboardData {
  const PurchaseDashboardData({
    required this.pendingApplyCount,
    required this.appliedCount,
    required this.purchasingCount,
    required this.pendingReceiveCount,
    required this.stockedThisMonthCount,
    required this.actionRequired,
  });

  final int pendingApplyCount;
  final int appliedCount;
  final int purchasingCount;
  final int pendingReceiveCount;
  final int stockedThisMonthCount;
  final List<PurchaseRequestSummary> actionRequired;
}
