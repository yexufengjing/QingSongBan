import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/maintenance_options.dart';

class LifecycleRepository {
  const LifecycleRepository(this._database);

  final AppDatabase _database;

  Stream<List<ComponentLifecycleRecord>> watchCurrent(int vehicleId) {
    return (_database.select(_database.componentLifecycleRecords)
          ..where(
            (table) =>
                table.vehicleId.equals(vehicleId) &
                table.isDeleted.equals(false) &
                table.status.equalsValue(LifecycleStatus.inUse),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.name)]))
        .watch();
  }

  Future<ComponentLifecycleRecord> save(LifecycleRecordDraft draft) async {
    if (draft.name.trim().isEmpty) throw ArgumentError('寿命件名称不能为空');
    if (draft.thresholdDays != null && draft.thresholdDays! < 0) {
      throw ArgumentError('寿命提醒天数不能为负数');
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
    final id = await _database
        .into(_database.componentLifecycleRecords)
        .insert(
          ComponentLifecycleRecordsCompanion.insert(
            vehicleId: draft.vehicleId,
            componentType: draft.componentType.trim(),
            componentKey: draft.componentKey.trim(),
            name: draft.name.trim(),
            installedDate: AppDateUtils.dateOnly(draft.installedDate),
            status: Value(draft.status),
            thresholdDays: Value(draft.thresholdDays),
            remark: Value(_nullable(draft.remark)),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return (_database.select(
      _database.componentLifecycleRecords,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  static int usageDays(ComponentLifecycleRecord record, {DateTime? onDate}) {
    final end =
        record.removedDate ?? AppDateUtils.dateOnly(onDate ?? DateTime.now());
    final days = AppDateUtils.dateOnly(end)
        .difference(AppDateUtils.dateOnly(record.installedDate))
        .inDays;
    return days < 0 ? 0 : days;
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
