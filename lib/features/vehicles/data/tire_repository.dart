import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/tire_options.dart';

class TireRepository {
  const TireRepository(this._database);

  final AppDatabase _database;

  Future<List<Tire>> listAssets({bool includeDeleted = false}) {
    final query = _database.select(_database.tires)
      ..orderBy([(table) => OrderingTerm(expression: table.tireNo)]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.get();
  }

  Future<Tire?> findById(int id) {
    return (_database.select(
      _database.tires,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<Tire> saveAsset({int? id, required TireDraft draft}) async {
    final tireNo = draft.tireNo.trim();
    if (tireNo.isEmpty) throw ArgumentError('轮胎内部编号不能为空');
    final now = DateTime.now();
    final values = TiresCompanion(
      tireNo: Value(tireNo),
      brand: Value(_nullable(draft.brand)),
      specification: Value(_nullable(draft.specification)),
      condition: Value(draft.condition),
      firstUseDate: Value(draft.firstUseDate),
      status: Value(draft.status),
      wearLevel: Value(draft.wearLevel),
      remark: Value(_nullable(draft.remark)),
      updatedAt: Value(now),
      isDeleted: const Value(false),
    );
    late final int tireId;
    if (id == null) {
      tireId = await _database
          .into(_database.tires)
          .insert(
            TiresCompanion.insert(
              tireNo: tireNo,
              brand: Value(_nullable(draft.brand)),
              specification: Value(_nullable(draft.specification)),
              condition: Value(draft.condition),
              firstUseDate: Value(draft.firstUseDate),
              status: Value(draft.status),
              wearLevel: Value(draft.wearLevel),
              remark: Value(_nullable(draft.remark)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } else {
      final existing = await findById(id);
      if (existing == null) throw StateError('轮胎不存在');
      await (_database.update(
        _database.tires,
      )..where((table) => table.id.equals(id))).write(values);
      tireId = id;
    }
    return (await findById(tireId))!;
  }

  Future<List<TireInstallation>> listCurrentInstallations(int vehicleId) {
    return (_database.select(_database.tireInstallations)
          ..where(
            (table) =>
                table.vehicleId.equals(vehicleId) & table.isActive.equals(true),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.position)]))
        .get();
  }

  Stream<List<TireInstallation>> watchCurrentInstallations(int vehicleId) {
    return (_database.select(_database.tireInstallations)
          ..where(
            (table) =>
                table.vehicleId.equals(vehicleId) & table.isActive.equals(true),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.position)]))
        .watch();
  }

  Future<List<TireInstallation>> listHistory(int tireId) {
    return (_database.select(_database.tireInstallations)
          ..where((table) => table.tireId.equals(tireId))
          ..orderBy([
            (table) => OrderingTerm(
              expression: table.installDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<TireInstallation> installTire({
    required int tireId,
    required int vehicleId,
    required TirePosition position,
    required DateTime installDate,
    TireInstallReason reason = TireInstallReason.newReplacement,
    String? note,
  }) async {
    late final int installationId;
    await _database.transaction(() async {
      await _requireVehicle(vehicleId);
      final tire = await _requireTire(tireId);
      await _ensurePositionAvailable(vehicleId, position);
      await _ensureTireAvailable(tireId);
      final now = DateTime.now();
      installationId = await _database
          .into(_database.tireInstallations)
          .insert(
            TireInstallationsCompanion.insert(
              tireId: tireId,
              vehicleId: vehicleId,
              position: position,
              installDate: AppDateUtils.dateOnly(installDate),
              installReason: reason,
              note: Value(_nullable(note)),
              createdAt: Value(now),
            ),
          );
      await (_database.update(
        _database.tires,
      )..where((table) => table.id.equals(tireId))).write(
        TiresCompanion(
          status: const Value(TireAssetStatus.inUse),
          firstUseDate: Value(
            tire.firstUseDate ?? AppDateUtils.dateOnly(installDate),
          ),
          updatedAt: Value(now),
        ),
      );
    });
    return (await (_database.select(
      _database.tireInstallations,
    )..where((table) => table.id.equals(installationId))).getSingle());
  }

  Future<void> relocateTire({
    required int vehicleId,
    required TirePosition damagedPosition,
    required TirePosition sourcePosition,
    required int replacementTireId,
    required DateTime date,
    TireAssetStatus damagedResultStatus = TireAssetStatus.removed,
    String? note,
  }) async {
    if (damagedPosition == sourcePosition) {
      throw ArgumentError('受损轮位和调位来源不能相同');
    }
    if (damagedResultStatus != TireAssetStatus.removed &&
        damagedResultStatus != TireAssetStatus.scrapped) {
      throw ArgumentError('受损轮胎只能标记为已拆下或报废');
    }
    await _database.transaction(() async {
      await _requireVehicle(vehicleId);
      final damaged = await _activeAt(vehicleId, damagedPosition);
      final source = await _activeAt(vehicleId, sourcePosition);
      if (damaged == null || source == null) {
        throw StateError('受损轮位和调位来源都必须已有在用轮胎');
      }
      if (replacementTireId == damaged.tireId ||
          replacementTireId == source.tireId) {
        throw StateError('替换轮胎不能是当前轮位中的轮胎');
      }
      await _requireTire(replacementTireId);
      await _ensureTireAvailable(replacementTireId);
      final normalizedDate = AppDateUtils.dateOnly(date);
      final now = DateTime.now();
      await (_database.update(
        _database.tireInstallations,
      )..where((table) => table.id.isIn([damaged.id, source.id]))).write(
        TireInstallationsCompanion(
          removeDate: Value(normalizedDate),
          removeReason: const Value('relocation'),
          isActive: const Value(false),
        ),
      );
      await _database.batch((batch) {
        batch.insert(
          _database.tireInstallations,
          TireInstallationsCompanion.insert(
            tireId: replacementTireId,
            vehicleId: vehicleId,
            position: sourcePosition,
            installDate: normalizedDate,
            installReason: TireInstallReason.newReplacement,
            note: Value(_nullable(note)),
            createdAt: Value(now),
          ),
        );
        batch.insert(
          _database.tireInstallations,
          TireInstallationsCompanion.insert(
            tireId: source.tireId,
            vehicleId: vehicleId,
            position: damagedPosition,
            installDate: normalizedDate,
            installReason: TireInstallReason.relocation,
            sourcePosition: Value(TireOptions.positionCode(sourcePosition)),
            note: Value(_nullable(note)),
            createdAt: Value(now),
          ),
        );
      });
      await (_database.update(
        _database.tires,
      )..where((table) => table.id.equals(replacementTireId))).write(
        TiresCompanion(
          status: const Value(TireAssetStatus.inUse),
          firstUseDate: Value(
            (await _requireTire(replacementTireId)).firstUseDate ??
                normalizedDate,
          ),
          updatedAt: Value(now),
        ),
      );
      await (_database.update(
        _database.tires,
      )..where((table) => table.id.equals(source.tireId))).write(
        TiresCompanion(
          status: const Value(TireAssetStatus.inUse),
          updatedAt: Value(now),
        ),
      );
      await (_database.update(
        _database.tires,
      )..where((table) => table.id.equals(damaged.tireId))).write(
        TiresCompanion(
          status: Value(damagedResultStatus),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<TireRepair> recordRepair({
    required int tireId,
    required DateTime repairDate,
    required TireRepairType repairType,
    required TireRepairSeverity severity,
    String? repairPosition,
    int amountCents = 0,
    String? vendor,
    String? remark,
  }) async {
    if (amountCents < 0) throw ArgumentError('修补费用不能为负数');
    late final int repairId;
    await _database.transaction(() async {
      final tire = await _requireTire(tireId);
      final now = DateTime.now();
      repairId = await _database
          .into(_database.tireRepairs)
          .insert(
            TireRepairsCompanion.insert(
              tireId: tireId,
              repairDate: AppDateUtils.dateOnly(repairDate),
              repairType: repairType,
              repairPosition: Value(_nullable(repairPosition)),
              severity: severity,
              amountCents: Value(amountCents),
              vendor: Value(_nullable(vendor)),
              remark: Value(_nullable(remark)),
              createdAt: Value(now),
            ),
          );
      await (_database.update(
        _database.tires,
      )..where((table) => table.id.equals(tireId))).write(
        TiresCompanion(
          repairCount: Value(tire.repairCount + 1),
          updatedAt: Value(now),
        ),
      );
    });
    return (_database.select(
      _database.tireRepairs,
    )..where((table) => table.id.equals(repairId))).getSingle();
  }

  Future<TireInstallation?> _activeAt(int vehicleId, TirePosition position) {
    return (_database.select(_database.tireInstallations)..where(
          (table) =>
              table.vehicleId.equals(vehicleId) &
              table.position.equalsValue(position) &
              table.isActive.equals(true),
        ))
        .getSingleOrNull();
  }

  Future<void> _ensurePositionAvailable(
    int vehicleId,
    TirePosition position,
  ) async {
    if (await _activeAt(vehicleId, position) != null) {
      throw StateError('${TireOptions.positionLabel(position)}已有在用轮胎');
    }
  }

  Future<void> _ensureTireAvailable(int tireId) async {
    final current =
        await (_database.select(_database.tireInstallations)..where(
              (table) =>
                  table.tireId.equals(tireId) & table.isActive.equals(true),
            ))
            .getSingleOrNull();
    if (current != null) throw StateError('该轮胎已安装在其他轮位');
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

  Future<Tire> _requireTire(int tireId) async {
    final tire =
        await (_database.select(_database.tires)..where(
              (table) =>
                  table.id.equals(tireId) & table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (tire == null) throw StateError('轮胎不存在或已删除');
    return tire;
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static int usageDays(TireInstallation installation, {DateTime? onDate}) {
    final end = AppDateUtils.dateOnly(onDate ?? DateTime.now());
    final start = AppDateUtils.dateOnly(installation.installDate);
    final effectiveEnd = installation.removeDate == null
        ? end
        : AppDateUtils.dateOnly(installation.removeDate!);
    final days = effectiveEnd.difference(start).inDays;
    return days < 0 ? 0 : days;
  }

  static int cumulativeUsageDays(
    List<TireInstallation> installations, {
    DateTime? onDate,
  }) {
    return installations.fold<int>(
      0,
      (sum, item) => sum + usageDays(item, onDate: onDate),
    );
  }
}
