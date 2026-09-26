import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/repair_options.dart';
import 'vehicle_scope.dart';

class RepairRepository {
  const RepairRepository(this._database);

  final AppDatabase _database;

  Stream<List<RepairOrder>> watchOrders({int? vehicleId}) {
    final query = _database.select(_database.repairOrders)
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.reportDate, mode: OrderingMode.desc),
      ]);
    if (vehicleId != null) {
      query.where((table) => table.vehicleId.equals(vehicleId));
    }
    return query.watch();
  }

  Future<RepairOrder?> findById(int id) {
    return (_database.select(_database.repairOrders)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Stream<List<RepairOrder>> watchAllOrders() => watchOrders();

  Future<int> updateMarkers({
    required int id,
    VehicleRepairStatus? status,
    RepairTicketStatus? ticketStatus,
    bool? isSettled,
    bool? isPaid,
  }) async {
    final order = await findById(id);
    if (order == null) throw StateError('维修单不存在');
    final now = DateTime.now();
    return _database.transaction(() async {
      final changed =
          await (_database.update(_database.repairOrders)..where(
                (table) => table.id.equals(id) & table.isDeleted.equals(false),
              ))
              .write(
                RepairOrdersCompanion(
                  status: status == null ? const Value.absent() : Value(status),
                  ticketStatus: ticketStatus == null
                      ? const Value.absent()
                      : Value(ticketStatus),
                  isSettled: isSettled == null
                      ? const Value.absent()
                      : Value(isSettled),
                  settledAt: isSettled == null
                      ? const Value.absent()
                      : Value(isSettled ? now : null),
                  isPaid: isPaid == null ? const Value.absent() : Value(isPaid),
                  paidAt: isPaid == null
                      ? const Value.absent()
                      : Value(isPaid ? now : null),
                  completedAt: status == null
                      ? const Value.absent()
                      : Value(
                          status == VehicleRepairStatus.completed ? now : null,
                        ),
                  updatedAt: Value(now),
                ),
              );
      if (status != null) await _syncVehicleStatus(order.vehicleId, now);
      return changed;
    });
  }

  Future<List<RepairCostItem>> listCosts(int repairOrderId) {
    return (_database.select(_database.repairCostItems)
          ..where(
            (table) =>
                table.repairOrderId.equals(repairOrderId) &
                table.isDeleted.equals(false),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.id)]))
        .get();
  }

  Future<List<RepairPart>> listParts(int repairOrderId) {
    return (_database.select(_database.repairParts)
          ..where(
            (table) =>
                table.repairOrderId.equals(repairOrderId) &
                table.isDeleted.equals(false),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.id)]))
        .get();
  }

  Future<RepairOrder> save({int? id, required RepairOrderDraft draft}) async {
    final symptom = draft.symptom.trim();
    if (symptom.isEmpty) throw ArgumentError('故障现象不能为空');
    if (draft.reportedAmountCents < 0) throw ArgumentError('申报金额不能为负数');
    final vehicle =
        await (_database.select(_database.vehicles)..where(
              (table) =>
                  table.id.equals(draft.vehicleId) &
                  table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (vehicle == null) throw StateError('车辆不存在或已删除');
    for (final cost in draft.costs) {
      if (cost.content.trim().isEmpty) throw ArgumentError('维修费用项目不能为空');
      if (cost.quantity <= 0 || cost.unitPriceCents < 0) {
        throw ArgumentError('维修费用数量和单价无效');
      }
    }
    final now = DateTime.now();
    late final int orderId;
    await _database.transaction(() async {
      final existing = id == null ? null : await findById(id);
      if (id != null && existing == null) throw StateError('维修单不存在');
      if (existing != null && existing.vehicleId != draft.vehicleId) {
        throw StateError('维修单不属于当前车辆：$id');
      }
      final completedAt = draft.status == VehicleRepairStatus.completed
          ? (draft.completedAt ?? now)
          : null;
      orderId =
          id ??
          await _database
              .into(_database.repairOrders)
              .insert(
                RepairOrdersCompanion.insert(
                  repairNo: _nextRepairNo(),
                  vehicleId: draft.vehicleId,
                  reportDate: AppDateUtils.dateOnly(draft.reportDate),
                  faultFoundAt: draft.faultFoundAt,
                  symptom: symptom,
                  cause: Value(_nullable(draft.cause)),
                  project: Value(_nullable(draft.project)),
                  departAt: Value(draft.departAt),
                  vendor: Value(_nullable(draft.vendor)),
                  manager: Value(_nullable(draft.manager)),
                  reportedAmountCents: Value(draft.reportedAmountCents),
                  actualAmountCents: Value(_total(draft.costs)),
                  ticketStatus: draft.ticketStatus,
                  status: Value(draft.status),
                  completedAt: Value(completedAt),
                  recordText: Value(_recordText(draft)),
                  remark: Value(_nullable(draft.remark)),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
      if (existing != null) {
        final existingId = existing.id;
        await (_database.update(_database.repairOrders)..where(
              (table) =>
                  table.id.equals(existingId) &
                  table.vehicleId.equals(draft.vehicleId),
            ))
            .write(
              RepairOrdersCompanion(
                vehicleId: Value(draft.vehicleId),
                reportDate: Value(AppDateUtils.dateOnly(draft.reportDate)),
                faultFoundAt: Value(draft.faultFoundAt),
                symptom: Value(symptom),
                cause: Value(_nullable(draft.cause)),
                project: Value(_nullable(draft.project)),
                departAt: Value(draft.departAt),
                vendor: Value(_nullable(draft.vendor)),
                manager: Value(_nullable(draft.manager)),
                reportedAmountCents: Value(draft.reportedAmountCents),
                actualAmountCents: Value(_total(draft.costs)),
                ticketStatus: Value(draft.ticketStatus),
                status: Value(draft.status),
                completedAt: Value(completedAt),
                recordText: Value(_recordText(draft)),
                remark: Value(_nullable(draft.remark)),
                updatedAt: Value(now),
              ),
            );
        await (_database.update(
          _database.repairCostItems,
        )..where((table) => table.repairOrderId.equals(existingId))).write(
          RepairCostItemsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(now),
          ),
        );
        await (_database.update(_database.repairParts)
              ..where((table) => table.repairOrderId.equals(existingId)))
            .write(const RepairPartsCompanion(isDeleted: Value(true)));
      }
      final costItemIds = <int>[];
      for (final cost in draft.costs) {
        costItemIds.add(
          await _database
              .into(_database.repairCostItems)
              .insert(
                RepairCostItemsCompanion.insert(
                  repairOrderId: orderId,
                  content: cost.content.trim(),
                  quantity: Value(cost.quantity),
                  unit: Value(
                    cost.unit.trim().isEmpty ? '项' : cost.unit.trim(),
                  ),
                  unitPriceCents: cost.unitPriceCents,
                  subtotalCents: cost.subtotalCents,
                  costType: cost.costType,
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              ),
        );
      }
      for (final part in draft.parts) {
        if (part.name.trim().isEmpty) throw ArgumentError('备件名称不能为空');
        if (part.tireId != null) {
          final linkedTire =
              await (_database.select(_database.tireInstallations)..where(
                    (table) =>
                        table.tireId.equals(part.tireId!) &
                        table.vehicleId.equals(draft.vehicleId),
                  ))
                  .getSingleOrNull();
          if (linkedTire == null) {
            throw StateError('备件轮胎不属于当前车辆：${part.tireId}');
          }
        }
        final costItemId =
            part.costItemIndex == null ||
                part.costItemIndex! < 0 ||
                part.costItemIndex! >= costItemIds.length
            ? null
            : costItemIds[part.costItemIndex!];
        await _database
            .into(_database.repairParts)
            .insert(
              RepairPartsCompanion.insert(
                repairOrderId: orderId,
                costItemId: Value(costItemId),
                tireId: Value(part.tireId),
                name: part.name.trim(),
                quantity: Value(part.quantity),
                unit: Value(part.unit),
                amountCents: Value(part.amountCents),
                componentType: Value(_nullable(part.componentType)),
                remark: Value(_nullable(part.remark)),
                createdAt: Value(now),
              ),
            );
      }
      await _syncVehicleStatus(draft.vehicleId, now);
    });
    final saved = await findById(orderId);
    if (saved == null) throw StateError('维修单保存后无法读取');
    return saved;
  }

  Future<int> totalCostCents(int repairOrderId) async {
    final costs = await listCosts(repairOrderId);
    return costs.fold<int>(0, (sum, item) => sum + item.subtotalCents);
  }

  Future<int> setStatus({
    required int id,
    required int vehicleId,
    required VehicleRepairStatus status,
  }) async {
    final order = await VehicleScope.requireRepairForVehicle(
      _database,
      repairOrderId: id,
      vehicleId: vehicleId,
    );
    final now = DateTime.now();
    await _database.transaction(() async {
      await (_database.update(_database.repairOrders)..where(
            (table) => table.id.equals(id) & table.vehicleId.equals(vehicleId),
          ))
          .write(
            RepairOrdersCompanion(
              status: Value(status),
              completedAt: Value(
                status == VehicleRepairStatus.completed ? now : null,
              ),
              updatedAt: Value(now),
            ),
          );
      await _syncVehicleStatus(order.vehicleId, now);
    });
    return id;
  }

  Future<void> _syncVehicleStatus(int vehicleId, DateTime now) async {
    final vehicle = await VehicleScope.requireVehicle(_database, vehicleId);
    if (vehicle.status == VehicleStatus.stopped ||
        vehicle.status == VehicleStatus.scrapped) {
      return;
    }
    final orders =
        await (_database.select(_database.repairOrders)..where(
              (table) =>
                  table.vehicleId.equals(vehicleId) &
                  table.isDeleted.equals(false),
            ))
            .get();
    final nextStatus =
        orders.any((order) => order.status == VehicleRepairStatus.repairing)
        ? VehicleStatus.repairing
        : orders.any(
            (order) =>
                order.status == VehicleRepairStatus.reported ||
                order.status == VehicleRepairStatus.pendingRepair,
          )
        ? VehicleStatus.pendingRepair
        : VehicleStatus.normal;
    if (vehicle.status != nextStatus) {
      await (_database.update(
        _database.vehicles,
      )..where((table) => table.id.equals(vehicleId))).write(
        VehiclesCompanion(status: Value(nextStatus), updatedAt: Value(now)),
      );
    }
  }

  int _total(List<RepairCostDraft> costs) =>
      costs.fold(0, (sum, item) => sum + item.subtotalCents);

  String _nextRepairNo() => 'REPAIR-${DateTime.now().microsecondsSinceEpoch}';

  String _recordText(RepairOrderDraft draft) {
    final date = AppDateUtils.formatDate(draft.reportDate);
    final costText = draft.costs.isEmpty
        ? '暂无费用明细'
        : draft.costs.indexed
              .map(
                (entry) =>
                    '${entry.$1 + 1}. ${entry.$2.content} ${entry.$2.quantity}${entry.$2.unit} × ${_yuan(entry.$2.unitPriceCents)}元 = ${_yuan(entry.$2.subtotalCents)}元',
              )
              .join('；');
    return '$date，故障：${draft.symptom.trim()}。费用：$costText；合计${_yuan(_total(draft.costs))}元。';
  }

  String _yuan(int cents) => (cents / 100).toStringAsFixed(2);

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
