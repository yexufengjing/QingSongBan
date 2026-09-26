import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/vehicles/data/repair_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/repair_options.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';

void main() {
  late AppDatabase database;
  late RepairRepository repository;
  late int vehicleId;

  setUp(() async {
    database = AppDatabase.forTesting();
    repository = RepairRepository(database);
    vehicleId = (await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '2号洒水车',
        vehicleNo: 'WT-002',
        vehicleType: VehicleType.waterTruck,
      ),
    )).id;
  });

  tearDown(() => database.close());

  test(
    'calculates repair totals from cost items and generates record text',
    () async {
      final order = await repository.save(
        draft: RepairOrderDraft(
          vehicleId: vehicleId,
          reportDate: DateTime(2026, 9, 18),
          faultFoundAt: DateTime(2026, 9, 18, 8, 30),
          symptom: '前喷无压力',
          ticketStatus: RepairTicketStatus.notRequired,
          costs: const [
            RepairCostDraft(
              content: '水管',
              quantity: 2,
              unit: '根',
              unitPriceCents: 3500,
              costType: RepairCostType.material,
            ),
            RepairCostDraft(
              content: '接头',
              quantity: 4,
              unit: '个',
              unitPriceCents: 800,
              costType: RepairCostType.part,
            ),
            RepairCostDraft(
              content: '工时费',
              quantity: 1,
              unit: '项',
              unitPriceCents: 8000,
              costType: RepairCostType.labor,
            ),
          ],
        ),
      );

      expect(order.actualAmountCents, 18200);
      expect(order.recordText, contains('前喷无压力'));
      expect(order.recordText, contains('合计182.00元'));
      expect(await repository.totalCostCents(order.id), 18200);
      expect(
        (await VehicleRepository(database).findById(vehicleId))?.status,
        VehicleStatus.pendingRepair,
      );
    },
  );

  test(
    'editing a repair replaces active cost rows and status flows to repairing',
    () async {
      final first = await repository.save(
        draft: RepairOrderDraft(
          vehicleId: vehicleId,
          reportDate: DateTime(2026, 9, 1),
          faultFoundAt: DateTime(2026, 9, 1),
          symptom: '水泵异响',
          ticketStatus: RepairTicketStatus.notIssued,
          costs: const [
            RepairCostDraft(
              content: '旧项目',
              quantity: 1,
              unit: '项',
              unitPriceCents: 1000,
              costType: RepairCostType.other,
            ),
          ],
        ),
      );
      final edited = await repository.save(
        id: first.id,
        draft: RepairOrderDraft(
          vehicleId: vehicleId,
          reportDate: DateTime(2026, 9, 1),
          faultFoundAt: DateTime(2026, 9, 1),
          symptom: '水泵异响',
          ticketStatus: RepairTicketStatus.notIssued,
          status: VehicleRepairStatus.repairing,
          costs: const [
            RepairCostDraft(
              content: '新项目',
              quantity: 1,
              unit: '项',
              unitPriceCents: 2500,
              costType: RepairCostType.part,
            ),
          ],
        ),
      );

      expect(edited.actualAmountCents, 2500);
      expect((await repository.listCosts(first.id)).single.content, '新项目');
      expect(
        (await VehicleRepository(database).findById(vehicleId))?.status,
        VehicleStatus.repairing,
      );
      expect(
        (await database.select(database.repairCostItems).get())
            .where((item) => item.isDeleted)
            .length,
        1,
      );
    },
  );

  test('completion and cancellation recalculate vehicle status', () async {
    final first = await repository.save(
      draft: RepairOrderDraft(
        vehicleId: vehicleId,
        reportDate: DateTime(2026, 9, 1),
        faultFoundAt: DateTime(2026, 9, 1),
        symptom: '制动异响',
        ticketStatus: RepairTicketStatus.notRequired,
      ),
    );
    final second = await repository.save(
      draft: RepairOrderDraft(
        vehicleId: vehicleId,
        reportDate: DateTime(2026, 9, 2),
        faultFoundAt: DateTime(2026, 9, 2),
        symptom: '灯光故障',
        ticketStatus: RepairTicketStatus.notRequired,
        status: VehicleRepairStatus.repairing,
      ),
    );
    expect(
      (await VehicleRepository(database).findById(vehicleId))?.status,
      VehicleStatus.repairing,
    );

    final completed = await repository.setStatus(
      id: second.id,
      vehicleId: vehicleId,
      status: VehicleRepairStatus.completed,
    );
    expect(completed, second.id);
    final completedOrder = await repository.findById(second.id);
    expect(completedOrder?.completedAt, isNotNull);
    expect(
      (await VehicleRepository(database).findById(vehicleId))?.status,
      VehicleStatus.pendingRepair,
    );

    await repository.setStatus(
      id: first.id,
      vehicleId: vehicleId,
      status: VehicleRepairStatus.cancelled,
    );
    expect(
      (await VehicleRepository(database).findById(vehicleId))?.status,
      VehicleStatus.normal,
    );
  });

  test('business markers update without replacing costs or parts', () async {
    final order = await repository.save(
      draft: RepairOrderDraft(
        vehicleId: vehicleId,
        reportDate: DateTime(2026, 9, 3),
        faultFoundAt: DateTime(2026, 9, 3),
        symptom: '发动机异响',
        ticketStatus: RepairTicketStatus.notIssued,
        costs: const [
          RepairCostDraft(
            content: '工时',
            quantity: 1,
            unit: '项',
            unitPriceCents: 9000,
            costType: RepairCostType.labor,
          ),
        ],
        parts: const [
          RepairPartDraft(
            name: '滤芯',
            quantity: 1,
            unit: '个',
            amountCents: 1200,
          ),
        ],
      ),
    );
    final beforeCosts = await repository.listCosts(order.id);
    final beforeParts = await repository.listParts(order.id);
    await repository.save(
      id: order.id,
      draft: RepairOrderDraft(
        vehicleId: vehicleId,
        reportDate: order.reportDate,
        faultFoundAt: order.faultFoundAt,
        symptom: order.symptom,
        ticketStatus: order.ticketStatus,
        costs: [
          for (final c in beforeCosts)
            RepairCostDraft(
              content: c.content,
              quantity: c.quantity,
              unit: c.unit,
              unitPriceCents: c.unitPriceCents,
              costType: c.costType,
            ),
        ],
        parts: [
          for (final p in beforeParts)
            RepairPartDraft(
              name: p.name,
              quantity: p.quantity,
              unit: p.unit,
              amountCents: p.amountCents,
              costItemIndex: p.costItemId == beforeCosts.first.id ? 0 : null,
              tireId: p.tireId,
              componentType: p.componentType,
              remark: p.remark,
            ),
        ],
      ),
    );
    final editedParts = await repository.listParts(order.id);
    expect(editedParts.single.name, '滤芯');
    final savedCosts = await repository.listCosts(order.id);
    final savedParts = await repository.listParts(order.id);
    await repository.updateMarkers(
      id: order.id,
      ticketStatus: RepairTicketStatus.issued,
      isSettled: true,
      isPaid: true,
    );
    final updated = (await repository.findById(order.id))!;
    expect(updated.ticketStatus, RepairTicketStatus.issued);
    expect(updated.isSettled, isTrue);
    expect(updated.settledAt, isNotNull);
    expect(updated.isPaid, isTrue);
    expect(updated.paidAt, isNotNull);
    expect(await repository.listCosts(order.id), savedCosts);
    expect(await repository.listParts(order.id), savedParts);
    await repository.updateMarkers(
      id: order.id,
      isSettled: false,
      isPaid: false,
    );
    final cleared = (await repository.findById(order.id))!;
    expect(cleared.settledAt, isNull);
    expect(cleared.paidAt, isNull);
  });

  test(
    'stopped and scrapped vehicles keep their manual strong state',
    () async {
      final vehicles = VehicleRepository(database);
      await vehicles.setStatus(vehicleId, VehicleStatus.stopped);
      await repository.save(
        draft: RepairOrderDraft(
          vehicleId: vehicleId,
          reportDate: DateTime(2026, 9, 1),
          faultFoundAt: DateTime(2026, 9, 1),
          symptom: '发动机故障',
          ticketStatus: RepairTicketStatus.notRequired,
          status: VehicleRepairStatus.repairing,
        ),
      );
      expect(
        (await vehicles.findById(vehicleId))?.status,
        VehicleStatus.stopped,
      );

      await vehicles.setStatus(vehicleId, VehicleStatus.scrapped);
      await repository.setStatus(
        id: (await repository.watchOrders(vehicleId: vehicleId).first)
            .single
            .id,
        vehicleId: vehicleId,
        status: VehicleRepairStatus.completed,
      );
      expect(
        (await vehicles.findById(vehicleId))?.status,
        VehicleStatus.scrapped,
      );
    },
  );
}
