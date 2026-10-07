abstract final class PurchaseRoutes {
  static const home = '/purchase';
  static const create = '/purchase/create';
  static const pendingApply = '/purchase/pending-apply';
  static const tracking = '/purchase/tracking';
  static const pendingReceive = '/purchase/pending-receive';
  static const history = '/purchase/history';

  static String detail(int id) => '/purchase/detail/$id';
  static String stockIn(int id) => '/purchase/stock-in/$id';
  static String itemHistory(int inventoryMaterialId) =>
      '/purchase/item-history/$inventoryMaterialId';
}
