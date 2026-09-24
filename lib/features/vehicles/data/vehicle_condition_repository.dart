import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../domain/condition_options.dart';

class VehicleConditionRepository {
  const VehicleConditionRepository(this._database);

  final AppDatabase _database;

  Stream<List<VehicleConditionItem>> watchCurrentItems(int vehicleId) {
    return (_database.select(_database.vehicleConditionItems)
          ..where(
            (table) =>
                table.vehicleId.equals(vehicleId) &
                table.isCurrent.equals(true) &
                table.isDeleted.equals(false),
          )
          ..orderBy([
            (table) => OrderingTerm(expression: table.componentType),
            (table) => OrderingTerm(expression: table.componentKey),
          ]))
        .watch();
  }

  Future<List<VehicleConditionItem>> listHistory(int vehicleId) {
    return (_database.select(_database.vehicleConditionItems)
          ..where(
            (table) =>
                table.vehicleId.equals(vehicleId) &
                table.isDeleted.equals(false),
          )
          ..orderBy([
            (table) => OrderingTerm(
              expression: table.observedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<VehicleConditionItem> save(VehicleConditionDraft draft) async {
    final componentType = draft.componentType.trim();
    final componentKey = draft.componentKey.trim();
    if (componentType.isEmpty || componentKey.isEmpty) {
      throw ArgumentError('车况部件不能为空');
    }
    final vehicle =
        await (_database.select(_database.vehicles)..where(
              (table) =>
                  table.id.equals(draft.vehicleId) &
                  table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (vehicle == null) throw StateError('车辆不存在或已删除');

    final now = DateTime.now();
    late final int itemId;
    await _database.transaction(() async {
      final snapshotId = await _database
          .into(_database.vehicleConditionSnapshots)
          .insert(
            VehicleConditionSnapshotsCompanion.insert(
              vehicleId: draft.vehicleId,
              checkedAt: draft.observedAt,
              createdAt: Value(now),
            ),
          );
      await (_database.update(_database.vehicleConditionItems)..where(
            (table) =>
                table.vehicleId.equals(draft.vehicleId) &
                table.componentType.equals(componentType) &
                table.componentKey.equals(componentKey) &
                table.isCurrent.equals(true) &
                table.isDeleted.equals(false),
          ))
          .write(
            VehicleConditionItemsCompanion(
              isCurrent: const Value(false),
              updatedAt: Value(now),
            ),
          );
      itemId = await _database
          .into(_database.vehicleConditionItems)
          .insert(
            VehicleConditionItemsCompanion.insert(
              vehicleId: draft.vehicleId,
              snapshotId: Value(snapshotId),
              componentType: componentType,
              componentKey: componentKey,
              status: draft.status,
              issueTagsJson: Value(jsonEncode(draft.issueTags)),
              detail: Value(_nullable(draft.detail)),
              observedAt: draft.observedAt,
              resolvedAt: Value(
                draft.status == VehicleConditionStatus.normal
                    ? draft.observedAt
                    : null,
              ),
              isCurrent: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });
    final item = await (_database.select(
      _database.vehicleConditionItems,
    )..where((table) => table.id.equals(itemId))).getSingleOrNull();
    if (item == null) throw StateError('车况保存后无法读取');
    return item;
  }

  List<String> decodeIssueTags(VehicleConditionItem item) {
    final raw = item.issueTagsJson;
    if (raw == null || raw.isEmpty) return const [];
    final value = jsonDecode(raw);
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
