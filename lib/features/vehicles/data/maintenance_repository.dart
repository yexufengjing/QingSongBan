import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../reminders/domain/reminder_options.dart';
import '../domain/maintenance_options.dart';
import 'vehicle_scope.dart';

class MaintenanceRepository {
  const MaintenanceRepository(this._database);

  final AppDatabase _database;

  Stream<List<VehicleMaintenanceItem>> watchItems(int vehicleId) {
    return (_database.select(_database.vehicleMaintenanceItems)
          ..where(
            (table) =>
                table.vehicleId.equals(vehicleId) &
                table.isDeleted.equals(false) &
                table.isActive.equals(true),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.name)]))
        .watch();
  }

  Future<List<MaintenanceTemplate>> listTemplates() {
    return (_database.select(_database.maintenanceTemplates)
          ..where(
            (table) =>
                table.isDeleted.equals(false) & table.isActive.equals(true),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
        .get();
  }

  Future<VehicleMaintenanceItem?> findItemById(int id) {
    return (_database.select(_database.vehicleMaintenanceItems)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<MaintenanceTemplate> saveTemplate(
    MaintenanceTemplateDraft draft, {
    int? id,
  }) async {
    if (draft.name.trim().isEmpty) throw ArgumentError('保养项目名称不能为空');
    _validateInterval(draft.intervalValue, draft.leadDays, draft.overdueDays);
    final now = DateTime.now();
    late final int templateId;
    if (id == null) {
      templateId = await _database
          .into(_database.maintenanceTemplates)
          .insert(
            MaintenanceTemplatesCompanion.insert(
              name: draft.name.trim(),
              componentType: Value(_nullable(draft.componentType)),
              intervalValue: draft.intervalValue,
              intervalUnit: draft.intervalUnit,
              leadDays: Value(draft.leadDays),
              overdueDays: Value(draft.overdueDays),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } else {
      templateId = id;
      await (_database.update(
        _database.maintenanceTemplates,
      )..where((table) => table.id.equals(id))).write(
        MaintenanceTemplatesCompanion(
          name: Value(draft.name.trim()),
          componentType: Value(_nullable(draft.componentType)),
          intervalValue: Value(draft.intervalValue),
          intervalUnit: Value(draft.intervalUnit),
          leadDays: Value(draft.leadDays),
          overdueDays: Value(draft.overdueDays),
          updatedAt: Value(now),
        ),
      );
    }
    return (await (_database.select(
      _database.maintenanceTemplates,
    )..where((table) => table.id.equals(templateId))).getSingle());
  }

  Future<VehicleMaintenanceItem> saveItem(
    VehicleMaintenanceItemDraft draft, {
    int? id,
  }) async {
    if (draft.name.trim().isEmpty) throw ArgumentError('保养项目名称不能为空');
    _validateInterval(draft.intervalValue, draft.leadDays, draft.overdueDays);
    await _requireVehicle(draft.vehicleId);
    final now = DateTime.now();
    final nextDueDate = draft.lastServiceDate == null
        ? null
        : calculateNextDueDate(
            draft.lastServiceDate!,
            draft.intervalValue,
            draft.intervalUnit,
          );
    late final int itemId;
    if (id == null) {
      itemId = await _database
          .into(_database.vehicleMaintenanceItems)
          .insert(
            VehicleMaintenanceItemsCompanion.insert(
              vehicleId: draft.vehicleId,
              templateId: Value(draft.templateId),
              name: draft.name.trim(),
              componentType: Value(_nullable(draft.componentType)),
              intervalValue: draft.intervalValue,
              intervalUnit: draft.intervalUnit,
              leadDays: Value(draft.leadDays),
              overdueDays: Value(draft.overdueDays),
              lastServiceDate: Value(draft.lastServiceDate),
              nextDueDate: Value(nextDueDate),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } else {
      itemId = id;
      final affected =
          await (_database.update(_database.vehicleMaintenanceItems)..where(
                (table) =>
                    table.id.equals(id) &
                    table.vehicleId.equals(draft.vehicleId) &
                    table.isDeleted.equals(false),
              ))
              .write(
                VehicleMaintenanceItemsCompanion(
                  vehicleId: Value(draft.vehicleId),
                  templateId: Value(draft.templateId),
                  name: Value(draft.name.trim()),
                  componentType: Value(_nullable(draft.componentType)),
                  intervalValue: Value(draft.intervalValue),
                  intervalUnit: Value(draft.intervalUnit),
                  leadDays: Value(draft.leadDays),
                  overdueDays: Value(draft.overdueDays),
                  lastServiceDate: Value(draft.lastServiceDate),
                  nextDueDate: Value(nextDueDate),
                  updatedAt: Value(now),
                ),
              );
      await VehicleScope.requireAffectedRows(affected, '保养项目不属于当前车辆或已删除：$id');
    }
    final item = await findItemById(itemId);
    if (item == null) throw StateError('保养项目保存后无法读取');
    await _syncMaintenanceReminder(item);
    return item;
  }

  Future<MaintenanceRecord> record(MaintenanceRecordDraft draft) async {
    if (draft.materialCostCents < 0 || draft.laborCostCents < 0) {
      throw ArgumentError('保养费用不能为负数');
    }
    final item = await findItemById(draft.maintenanceItemId);
    if (item == null || item.vehicleId != draft.vehicleId) {
      throw StateError('保养项目不存在');
    }
    final date = AppDateUtils.dateOnly(draft.serviceDate);
    final total = draft.materialCostCents + draft.laborCostCents;
    late final int recordId;
    await _database.transaction(() async {
      final now = DateTime.now();
      recordId = await _database
          .into(_database.maintenanceRecords)
          .insert(
            MaintenanceRecordsCompanion.insert(
              maintenanceItemId: draft.maintenanceItemId,
              vehicleId: draft.vehicleId,
              serviceDate: date,
              materialCostCents: Value(draft.materialCostCents),
              laborCostCents: Value(draft.laborCostCents),
              totalCostCents: Value(total),
              remark: Value(_nullable(draft.remark)),
              createdAt: Value(now),
            ),
          );
      await (_database.update(_database.vehicleMaintenanceItems)..where(
            (table) =>
                table.id.equals(draft.maintenanceItemId) &
                table.vehicleId.equals(draft.vehicleId),
          ))
          .write(
            VehicleMaintenanceItemsCompanion(
              lastServiceDate: Value(date),
              nextDueDate: Value(
                calculateNextDueDate(
                  date,
                  item.intervalValue,
                  item.intervalUnit,
                ),
              ),
              updatedAt: Value(now),
            ),
          );
    });
    final saved = await (_database.select(
      _database.maintenanceRecords,
    )..where((table) => table.id.equals(recordId))).getSingle();
    final updatedItem = await findItemById(draft.maintenanceItemId);
    if (updatedItem != null) await _syncMaintenanceReminder(updatedItem);
    return saved;
  }

  static MaintenanceDueStatus dueStatus(
    VehicleMaintenanceItem item, {
    DateTime? now,
  }) {
    final dueDate = item.nextDueDate;
    if (dueDate == null) return MaintenanceDueStatus.noRecord;
    final date = AppDateUtils.dateOnly(now ?? DateTime.now());
    final dueSoonDate = dueDate.subtract(Duration(days: item.leadDays));
    final overdueDate = dueDate.add(Duration(days: item.overdueDays));
    if (date.isBefore(dueSoonDate)) return MaintenanceDueStatus.normal;
    if (date.isBefore(dueDate)) return MaintenanceDueStatus.dueSoon;
    if (!date.isAfter(overdueDate)) return MaintenanceDueStatus.due;
    return MaintenanceDueStatus.overdue;
  }

  static DateTime calculateNextDueDate(
    DateTime date,
    int intervalValue,
    MaintenanceIntervalUnit unit,
  ) {
    final start = AppDateUtils.dateOnly(date);
    return switch (unit) {
      MaintenanceIntervalUnit.days => start.add(Duration(days: intervalValue)),
      MaintenanceIntervalUnit.months => _addCalendarMonths(
        start,
        intervalValue,
      ),
      MaintenanceIntervalUnit.years => _addCalendarMonths(
        start,
        intervalValue * 12,
      ),
    };
  }

  static DateTime _addCalendarMonths(DateTime date, int months) {
    final monthIndex = date.year * 12 + date.month - 1 + months;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day.clamp(1, lastDay).toInt());
  }

  Future<void> seedDefaultItems(int vehicleId) async {
    await _requireVehicle(vehicleId);
    final existing =
        await (_database.select(_database.vehicleMaintenanceItems)..where(
              (table) =>
                  table.vehicleId.equals(vehicleId) &
                  table.isDeleted.equals(false),
            ))
            .get();
    if (existing.isNotEmpty) return;
    const defaults = [
      ('主机机油', 'engine', 6, MaintenanceIntervalUnit.months),
      ('主机机油滤芯', 'engine', 6, MaintenanceIntervalUnit.months),
      ('副机机油', 'auxiliaryEngine', 6, MaintenanceIntervalUnit.months),
      ('副机机油滤芯', 'auxiliaryEngine', 6, MaintenanceIntervalUnit.months),
    ];
    for (final item in defaults) {
      await saveItem(
        VehicleMaintenanceItemDraft(
          vehicleId: vehicleId,
          name: item.$1,
          componentType: item.$2,
          intervalValue: item.$3,
          intervalUnit: item.$4,
        ),
      );
    }
  }

  Future<void> _syncMaintenanceReminder(VehicleMaintenanceItem item) async {
    if (item.nextDueDate == null) return;
    final vehicle = await (_database.select(
      _database.vehicles,
    )..where((table) => table.id.equals(item.vehicleId))).getSingleOrNull();
    if (vehicle == null) return;
    await ReminderRepository(_database).save(
      draft: ReminderDraft(
        title: '${vehicle.name} — ${item.name}到期提醒',
        reminderType: 'vehicleMaintenance',
        leadDays: item.leadDays,
        isEnabled: true,
        dueDate: item.nextDueDate,
        sourceEntityType: 'vehicleMaintenance',
        sourceEntityId: item.id,
        repeatRule: null,
        links: [
          ReminderLinkDraft(
            entityType: 'vehicle',
            entityId: vehicle.id,
            displayName: vehicle.name,
          ),
        ],
      ),
    );
  }

  Future<void> _requireVehicle(int vehicleId) async {
    final vehicle =
        await (_database.select(_database.vehicles)..where(
              (table) =>
                  table.id.equals(vehicleId) & table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (vehicle == null) throw StateError('车辆不存在或已删除');
  }

  void _validateInterval(int value, int leadDays, int overdueDays) {
    if (value <= 0) throw ArgumentError('保养周期必须大于 0');
    if (leadDays < 0 || overdueDays < 0) throw ArgumentError('提醒阈值不能为负数');
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
