import '../data/inventory_repository.dart';

/// Application-facing inventory API. All stock mutations are delegated to the
/// repository's single transactional path.
class InventoryService extends InventoryRepository {
  InventoryService(super.db);
}
