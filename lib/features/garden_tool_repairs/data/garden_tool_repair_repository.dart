import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/repair_models.dart';

class GardenToolRepairRepository {
  const GardenToolRepairRepository(this._database);

  final AppDatabase _database;

  static const maxAttachmentsPerGroup = 9;

  Stream<List<GardenToolRepairUnit>> watchUnits({
    bool includeInactive = false,
  }) {
    final query = _database.select(_database.gardenToolRepairUnits)
      ..orderBy([
        (table) => OrderingTerm(expression: table.sortOrder),
        (table) => OrderingTerm(expression: table.name),
      ]);
    if (!includeInactive) {
      query.where((table) => table.isActive.equals(true));
    }
    return query.watch();
  }

  Future<List<GardenToolRepairUnit>> listUnits({bool includeInactive = false}) {
    final query = _database.select(_database.gardenToolRepairUnits)
      ..orderBy([
        (table) => OrderingTerm(expression: table.sortOrder),
        (table) => OrderingTerm(expression: table.name),
      ]);
    if (!includeInactive) {
      query.where((table) => table.isActive.equals(true));
    }
    return query.get();
  }

  Stream<List<GardenToolRepairPerson>> watchPersons(
    int unitId, {
    bool includeInactive = false,
  }) {
    final query = _database.select(_database.gardenToolRepairPersons)
      ..where((table) => table.unitId.equals(unitId))
      ..orderBy([
        (table) => OrderingTerm(expression: table.sortOrder),
        (table) => OrderingTerm(expression: table.name),
      ]);
    if (!includeInactive) {
      query.where((table) => table.isActive.equals(true));
    }
    return query.watch();
  }

  Future<GardenToolRepairUnit> saveUnit({
    int? id,
    required String name,
    required int sortOrder,
    required bool isActive,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('维修单位不能为空');
    final now = DateTime.now();
    final values = GardenToolRepairUnitsCompanion(
      name: Value(normalizedName),
      sortOrder: Value(sortOrder),
      isActive: Value(isActive),
      updatedAt: Value(now),
    );
    final unitId =
        id ??
        await _database
            .into(_database.gardenToolRepairUnits)
            .insert(
              GardenToolRepairUnitsCompanion.insert(
                name: normalizedName,
                sortOrder: Value(sortOrder),
                isActive: Value(isActive),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
    if (id != null) {
      final affected = await (_database.update(
        _database.gardenToolRepairUnits,
      )..where((table) => table.id.equals(id))).write(values);
      if (affected == 0) throw StateError('维修单位不存在');
    }
    return (_database.select(
      _database.gardenToolRepairUnits,
    )..where((table) => table.id.equals(unitId))).getSingle();
  }

  Future<GardenToolRepairPerson> addPerson({
    required int unitId,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('维修人姓名不能为空');
    final unit = await (_database.select(
      _database.gardenToolRepairUnits,
    )..where((table) => table.id.equals(unitId))).getSingleOrNull();
    if (unit == null || !unit.isActive) throw StateError('维修单位不存在或已停用');
    final now = DateTime.now();
    final id = await _database
        .into(_database.gardenToolRepairPersons)
        .insert(
          GardenToolRepairPersonsCompanion.insert(
            unitId: unitId,
            name: normalizedName,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return (_database.select(
      _database.gardenToolRepairPersons,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  Stream<List<GardenToolRepairLedgerGroup>> watchMonth(DateTime month) {
    final query = _database.select(_database.gardenToolRepairGroups)
      ..where(
        (table) =>
            table.repairMonth.equals(repairMonthKey(month)) &
            table.deletedAt.isNull(),
      )
      ..orderBy([
        (table) => OrderingTerm(expression: table.repairDate),
        (table) => OrderingTerm(expression: table.createdAt),
        (table) => OrderingTerm(expression: table.id),
      ]);
    return query.watch().asyncMap(_withItems);
  }

  Future<List<GardenToolRepairLedgerGroup>> loadMonth(DateTime month) async {
    final groups =
        await (_database.select(_database.gardenToolRepairGroups)
              ..where(
                (table) =>
                    table.repairMonth.equals(repairMonthKey(month)) &
                    table.deletedAt.isNull(),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.repairDate),
                (table) => OrderingTerm(expression: table.createdAt),
                (table) => OrderingTerm(expression: table.id),
              ]))
            .get();
    return _withItems(groups);
  }

  Stream<List<GardenToolRepairLedgerGroup>> watchPeriod({
    required DateTime start,
    required DateTime endExclusive,
    int? unitId,
  }) {
    final query = _database.select(_database.gardenToolRepairGroups)
      ..where(
        (table) =>
            table.repairDate.isBiggerOrEqualValue(start) &
            table.repairDate.isSmallerThanValue(endExclusive) &
            table.deletedAt.isNull(),
      )
      ..orderBy([
        (table) => OrderingTerm(expression: table.repairDate),
        (table) => OrderingTerm(expression: table.createdAt),
      ]);
    if (unitId != null) {
      query.where((table) => table.unitId.equals(unitId));
    }
    return query.watch().asyncMap(_withItems);
  }

  Future<GardenToolRepairGroupDraft> copyDraft(int groupId) async {
    final group =
        await (_database.select(_database.gardenToolRepairGroups)..where(
              (table) => table.id.equals(groupId) & table.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (group == null) throw StateError('维修记录组不存在');
    final items =
        await (_database.select(_database.gardenToolRepairItems)
              ..where(
                (table) =>
                    table.groupId.equals(groupId) & table.deletedAt.isNull(),
              )
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();
    return GardenToolRepairLedgerGroup(group: group, items: items).toDraft();
  }

  Future<GardenToolRepairLedgerGroup?> loadGroup(int groupId) async {
    final group =
        await (_database.select(_database.gardenToolRepairGroups)..where(
              (table) => table.id.equals(groupId) & table.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (group == null) return null;
    return (await _withItems([group])).single;
  }

  Stream<List<GardenToolRepairAttachment>> watchAttachments(int groupId) {
    final query = _database.select(_database.gardenToolRepairAttachments)
      ..where(
        (table) => table.groupId.equals(groupId) & table.deletedAt.isNull(),
      )
      ..orderBy([
        (table) => OrderingTerm(expression: table.sortOrder),
        (table) => OrderingTerm(expression: table.createdAt),
      ]);
    return query.watch();
  }

  Future<GardenToolRepairAttachment> addAttachment({
    required int groupId,
    required String attachmentType,
    required String filePath,
    String? thumbnailPath,
  }) async {
    return _database.transaction(() async {
      final group =
          await (_database.select(_database.gardenToolRepairGroups)..where(
                (table) => table.id.equals(groupId) & table.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (group == null) throw StateError('维修记录组不存在或已删除');
      final current =
          await (_database.select(_database.gardenToolRepairAttachments)..where(
                (table) =>
                    table.groupId.equals(groupId) & table.deletedAt.isNull(),
              ))
              .get();
      if (current.length >= maxAttachmentsPerGroup) {
        throw StateError('每组最多添加 $maxAttachmentsPerGroup 张附件');
      }
      final id = await _database
          .into(_database.gardenToolRepairAttachments)
          .insert(
            GardenToolRepairAttachmentsCompanion.insert(
              groupId: groupId,
              attachmentType: attachmentType,
              filePath: filePath,
              thumbnailPath: Value(thumbnailPath),
              sortOrder: Value(current.length),
            ),
          );
      return (_database.select(
        _database.gardenToolRepairAttachments,
      )..where((table) => table.id.equals(id))).getSingle();
    });
  }

  Future<void> softDeleteAttachment(int attachmentId) async {
    final affected =
        await (_database.update(_database.gardenToolRepairAttachments)..where(
              (table) =>
                  table.id.equals(attachmentId) & table.deletedAt.isNull(),
            ))
            .write(
              GardenToolRepairAttachmentsCompanion(
                deletedAt: Value(DateTime.now()),
              ),
            );
    if (affected == 0) throw StateError('附件不存在或已删除');
  }

  Future<GardenToolRepairGroup> saveGroup(
    GardenToolRepairGroupDraft draft,
  ) async {
    final repairerName = draft.repairerName.trim();
    final monthDate = DateTime.tryParse('${draft.repairMonth}-01');
    if (monthDate == null || repairMonthKey(monthDate) != draft.repairMonth) {
      throw ArgumentError('维修月份无效');
    }
    if (repairMonthKey(draft.repairDate) != draft.repairMonth) {
      throw ArgumentError('维修日期必须属于选定维修月份');
    }
    if (repairerName.isEmpty) throw ArgumentError('维修人不能为空');
    if (draft.items.isEmpty) throw ArgumentError('至少添加一条维修明细');
    for (final item in draft.items) {
      if (item.projectName.trim().isEmpty) throw ArgumentError('项目名称不能为空');
      if (item.countUnit.trim().isEmpty) throw ArgumentError('计数单位不能为空');
      if (!item.quantity.isFinite || item.quantity <= 0) {
        throw ArgumentError('数量必须大于 0');
      }
      if (item.unitPriceCents < 0) throw ArgumentError('单价不能小于 0');
    }

    return _database.transaction(() async {
      final unit = await (_database.select(
        _database.gardenToolRepairUnits,
      )..where((table) => table.id.equals(draft.unitId))).getSingleOrNull();
      if (unit == null) throw StateError('维修单位不存在');
      if (draft.repairerId case final repairerId?) {
        final person =
            await (_database.select(_database.gardenToolRepairPersons)..where(
                  (table) =>
                      table.id.equals(repairerId) &
                      table.unitId.equals(draft.unitId),
                ))
                .getSingleOrNull();
        if (person == null) throw StateError('维修人不属于当前维修单位');
      }

      GardenToolRepairGroup? existing;
      if (draft.id case final groupId?) {
        existing =
            await (_database.select(_database.gardenToolRepairGroups)..where(
                  (table) =>
                      table.id.equals(groupId) & table.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (existing == null) throw StateError('维修记录组不存在或已删除');
      }
      if (!unit.isActive && existing?.unitId != unit.id) {
        throw StateError('已停用的维修单位不能用于新记录');
      }
      final unitSnapshot = existing?.unitId == unit.id
          ? existing!.unitNameSnapshot
          : unit.name;
      final now = DateTime.now();
      final groupValues = GardenToolRepairGroupsCompanion(
        repairMonth: Value(draft.repairMonth),
        repairDate: Value(
          DateTime(
            draft.repairDate.year,
            draft.repairDate.month,
            draft.repairDate.day,
          ),
        ),
        unitId: Value(unit.id),
        unitNameSnapshot: Value(unitSnapshot),
        repairerId: Value(draft.repairerId),
        repairerNameSnapshot: Value(repairerName),
        subtotalCents: Value(draft.subtotalCents),
        remark: Value(_nullable(draft.remark)),
        updatedAt: Value(now),
      );
      final groupId = existing == null
          ? await _database
                .into(_database.gardenToolRepairGroups)
                .insert(
                  GardenToolRepairGroupsCompanion.insert(
                    repairMonth: draft.repairMonth,
                    repairDate: DateTime(
                      draft.repairDate.year,
                      draft.repairDate.month,
                      draft.repairDate.day,
                    ),
                    unitId: unit.id,
                    unitNameSnapshot: unitSnapshot,
                    repairerId: Value(draft.repairerId),
                    repairerNameSnapshot: repairerName,
                    subtotalCents: Value(draft.subtotalCents),
                    remark: Value(_nullable(draft.remark)),
                    createdAt: Value(now),
                    updatedAt: Value(now),
                  ),
                )
          : existing.id;
      if (existing != null) {
        await (_database.update(
          _database.gardenToolRepairGroups,
        )..where((table) => table.id.equals(groupId))).write(groupValues);
        await (_database.update(_database.gardenToolRepairItems)..where(
              (table) =>
                  table.groupId.equals(groupId) & table.deletedAt.isNull(),
            ))
            .write(GardenToolRepairItemsCompanion(deletedAt: Value(now)));
      }
      for (var index = 0; index < draft.items.length; index++) {
        final item = draft.items[index];
        await _database
            .into(_database.gardenToolRepairItems)
            .insert(
              GardenToolRepairItemsCompanion.insert(
                groupId: groupId,
                projectName: item.projectName.trim(),
                specModel: Value(_nullable(item.specModel)),
                countUnit: item.countUnit.trim(),
                quantity: item.quantity,
                unitPriceCents: item.unitPriceCents,
                amountCents: item.amountCents,
                remark: Value(_nullable(item.remark)),
                sortOrder: Value(index),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
      return (_database.select(
        _database.gardenToolRepairGroups,
      )..where((table) => table.id.equals(groupId))).getSingle();
    });
  }

  Future<void> softDeleteGroup(int groupId) async {
    final now = DateTime.now();
    await _database.transaction(() async {
      final affected =
          await (_database.update(_database.gardenToolRepairGroups)..where(
                (table) => table.id.equals(groupId) & table.deletedAt.isNull(),
              ))
              .write(GardenToolRepairGroupsCompanion(deletedAt: Value(now)));
      if (affected == 0) throw StateError('维修记录组不存在或已删除');
      await (_database.update(_database.gardenToolRepairItems)..where(
            (table) => table.groupId.equals(groupId) & table.deletedAt.isNull(),
          ))
          .write(GardenToolRepairItemsCompanion(deletedAt: Value(now)));
      await (_database.update(_database.gardenToolRepairAttachments)..where(
            (table) => table.groupId.equals(groupId) & table.deletedAt.isNull(),
          ))
          .write(GardenToolRepairAttachmentsCompanion(deletedAt: Value(now)));
    });
  }

  Future<List<GardenToolRepairPricePoint>> loadPricePoints({
    required String projectName,
    required String specModel,
    required String countUnit,
    required DateTime start,
    required DateTime endExclusive,
    int? unitId,
  }) async {
    final items = _database.gardenToolRepairItems;
    final groups = _database.gardenToolRepairGroups;
    final units = _database.gardenToolRepairUnits;
    final query =
        _database.select(items).join([
          innerJoin(groups, groups.id.equalsExp(items.groupId)),
          innerJoin(units, units.id.equalsExp(groups.unitId)),
        ])..where(
          items.projectName.equals(projectName.trim()) &
              (specModel.trim().isEmpty
                  ? items.specModel.isNull()
                  : items.specModel.equals(specModel.trim())) &
              items.countUnit.equals(countUnit.trim()) &
              items.deletedAt.isNull() &
              groups.deletedAt.isNull() &
              groups.repairDate.isBiggerOrEqualValue(start) &
              groups.repairDate.isSmallerThanValue(endExclusive),
        );
    if (unitId != null) query.where(groups.unitId.equals(unitId));
    query.orderBy([
      OrderingTerm(expression: groups.repairDate, mode: OrderingMode.desc),
      OrderingTerm(expression: items.createdAt, mode: OrderingMode.desc),
      OrderingTerm(expression: items.id, mode: OrderingMode.desc),
    ]);
    final rows = await query.get();
    return rows
        .map(
          (row) => GardenToolRepairPricePoint(
            repairDate: row.readTable(groups).repairDate,
            unitName: row.readTable(units).name,
            repairerName: row.readTable(groups).repairerNameSnapshot,
            unitPriceCents: row.readTable(items).unitPriceCents,
          ),
        )
        .toList();
  }

  Future<List<GardenToolRepairPriceItemOption>> loadPriceItemOptions() async {
    final rows = await _database.customSelect('''
          SELECT DISTINCT
            i.project_name AS project_name,
            COALESCE(i.spec_model, '') AS spec_model,
            i.count_unit AS count_unit
          FROM garden_tool_repair_items i
          INNER JOIN garden_tool_repair_groups g ON g.id = i.group_id
          WHERE i.deleted_at IS NULL AND g.deleted_at IS NULL
          ORDER BY i.project_name, COALESCE(i.spec_model, ''), i.count_unit
        ''').get();
    return rows
        .map(
          (row) => GardenToolRepairPriceItemOption(
            projectName: row.read<String>('project_name'),
            specModel: row.read<String>('spec_model'),
            countUnit: row.read<String>('count_unit'),
          ),
        )
        .toList();
  }

  Future<List<GardenToolRepairLedgerGroup>> _withItems(
    List<GardenToolRepairGroup> groups,
  ) async {
    if (groups.isEmpty) return const [];
    final groupIds = groups.map((group) => group.id).toList();
    final items =
        await (_database.select(_database.gardenToolRepairItems)
              ..where(
                (table) =>
                    table.groupId.isIn(groupIds) & table.deletedAt.isNull(),
              )
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();
    final attachments =
        await (_database.select(_database.gardenToolRepairAttachments)..where(
              (table) =>
                  table.groupId.isIn(groupIds) & table.deletedAt.isNull(),
            ))
            .get();
    final itemsByGroup = <int, List<GardenToolRepairItem>>{};
    for (final item in items) {
      itemsByGroup.putIfAbsent(item.groupId, () => []).add(item);
    }
    final attachmentCounts = <int, int>{};
    for (final attachment in attachments) {
      attachmentCounts.update(
        attachment.groupId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return groups
        .map(
          (group) => GardenToolRepairLedgerGroup(
            group: group,
            items: itemsByGroup[group.id] ?? const [],
            attachmentCount: attachmentCounts[group.id] ?? 0,
          ),
        )
        .toList();
  }

  String? _nullable(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
