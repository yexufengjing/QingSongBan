enum PurchaseStatus {
  pendingApply('pending_apply', '待申报'),
  applied('applied', '已申报'),
  purchasing('purchasing', '采购中'),
  pendingReceive('pending_receive', '待领取'),
  stocked('stocked', '已入库'),
  cancelled('cancelled', '已取消');

  const PurchaseStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static PurchaseStatus parse(String value) => PurchaseStatus.values.firstWhere(
    (status) => status.storageValue == value,
  );

  bool get isActive => this != cancelled && this != stocked;

  static const normalFlow = <PurchaseStatus>[
    pendingApply,
    applied,
    purchasing,
    pendingReceive,
    stocked,
  ];
}

enum PurchaseFailureCode {
  invalidInput,
  notFound,
  invalidState,
  inventoryItemInactive,
  inventoryItemMissing,
  stockInsufficient,
  deletionForbidden,
  duplicateActiveRequest,
  conflict,
}

class PurchaseException implements Exception {
  const PurchaseException(this.code, this.message);

  final PurchaseFailureCode code;
  final String message;

  @override
  String toString() => 'PurchaseException(${code.name}): $message';
}
