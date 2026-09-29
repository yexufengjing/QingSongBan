import '../../../core/database/app_database.dart';

enum InventoryStockStatus { normal, low, outOfStock }

class InventoryOverview {
  const InventoryOverview({
    required this.totalMaterialCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.pendingReplenishmentCount,
    required this.monthlyReceiptCount,
    required this.monthlyIssueCount,
  });

  final int totalMaterialCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int pendingReplenishmentCount;
  final int monthlyReceiptCount;
  final int monthlyIssueCount;
}

class InventoryStockRow {
  const InventoryStockRow({required this.material, this.categoryName});

  final InventoryMaterial material;
  final String? categoryName;

  InventoryStockStatus get status {
    if (material.currentStock == 0) return InventoryStockStatus.outOfStock;
    if (material.currentStock <= material.minStock) {
      return InventoryStockStatus.low;
    }
    return InventoryStockStatus.normal;
  }
}

class InventoryMaterialDraft {
  const InventoryMaterialDraft({
    required this.materialCode,
    required this.materialName,
    required this.unitName,
    this.categoryId,
    this.modelSpec,
    this.storageLocation,
    this.minStock = 0,
    this.maxStock,
    this.defaultSource,
    this.referencePriceCent,
    this.warningEnabled = true,
    this.isCommon = false,
    this.status = 'active',
    this.remark,
  });

  final String materialCode;
  final String materialName;
  final String unitName;
  final int? categoryId;
  final String? modelSpec;
  final String? storageLocation;
  final double minStock;
  final double? maxStock;
  final String? defaultSource;
  final int? referencePriceCent;
  final bool warningEnabled;
  final bool isCommon;
  final String status;
  final String? remark;
}

class InventoryReceiptLineDraft {
  const InventoryReceiptLineDraft({
    required this.materialId,
    required this.quantity,
    this.referencePriceCent,
    this.replenishmentId,
    this.remark,
  });

  final int materialId;
  final double quantity;
  final int? referencePriceCent;
  final int? replenishmentId;
  final String? remark;
}

class InventoryReceiptDraft {
  const InventoryReceiptDraft({
    required this.receiptDate,
    required this.receiptType,
    required this.items,
    this.receiptNo,
    this.sourceName,
    this.operatorId,
    this.operatorName,
    this.remark,
  });

  final DateTime receiptDate;
  final String receiptType;
  final List<InventoryReceiptLineDraft> items;
  final String? receiptNo;
  final String? sourceName;
  final int? operatorId;
  final String? operatorName;
  final String? remark;
}

class InventoryIssueLineDraft {
  const InventoryIssueLineDraft({
    required this.materialId,
    required this.quantity,
    this.remark,
  });

  final int materialId;
  final double quantity;
  final String? remark;
}

class InventoryIssueDraft {
  const InventoryIssueDraft({
    required this.issueDate,
    required this.issueType,
    required this.receiverType,
    required this.items,
    this.issueNo,
    this.employeeId,
    this.employeeName,
    this.departmentName,
    this.manualReceiverName,
    this.purpose,
    this.operatorId,
    this.operatorName,
    this.remark,
    this.sourceType,
    this.sourceId,
  });

  final DateTime issueDate;
  final String issueType;
  final String receiverType;
  final List<InventoryIssueLineDraft> items;
  final String? issueNo;
  final int? employeeId;
  final String? employeeName;
  final String? departmentName;
  final String? manualReceiverName;
  final String? purpose;
  final int? operatorId;
  final String? operatorName;
  final String? remark;
  final String? sourceType;
  final int? sourceId;
}

class InventoryStocktakeLineDraft {
  const InventoryStocktakeLineDraft({
    required this.materialId,
    required this.actualQuantity,
    this.remark,
  });

  final int materialId;
  final double actualQuantity;
  final String? remark;
}

class InventoryStocktakeDraft {
  const InventoryStocktakeDraft({
    required this.stocktakeDate,
    required this.items,
    this.stocktakeNo,
    this.operatorId,
    this.operatorName,
    this.remark,
  });

  final DateTime stocktakeDate;
  final List<InventoryStocktakeLineDraft> items;
  final String? stocktakeNo;
  final int? operatorId;
  final String? operatorName;
  final String? remark;
}

class InventoryReplenishmentDraft {
  const InventoryReplenishmentDraft({
    this.materialId,
    required this.materialName,
    this.modelSpec,
    required this.unitName,
    required this.currentStock,
    required this.minStock,
    required this.suggestedQuantity,
    this.plannedQuantity,
    this.replenishMethod = 'central_store',
    this.reason,
    this.remark,
  });

  final int? materialId;
  final String materialName;
  final String? modelSpec;
  final String unitName;
  final double currentStock;
  final double minStock;
  final double suggestedQuantity;
  final double? plannedQuantity;
  final String replenishMethod;
  final String? reason;
  final String? remark;
}

class InventoryEmployeeHistoryItem {
  const InventoryEmployeeHistoryItem({required this.issue, required this.item});

  final InventoryIssue issue;
  final InventoryIssueItem item;
}
