import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../domain/vehicle_options.dart';

class VehicleRepository {
  const VehicleRepository(this._database);

  final AppDatabase _database;

  Stream<List<Vehicle>> watchVehicles({
    String search = '',
    VehicleType? type,
    VehicleStatus? status,
    bool includeDeleted = false,
  }) {
    final query = _database.select(_database.vehicles)
      ..orderBy([
        (table) => OrderingTerm(expression: table.name),
        (table) => OrderingTerm(expression: table.vehicleNo),
      ]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    if (type != null) {
      query.where((table) => table.vehicleType.equalsValue(type));
    }
    if (status != null) {
      query.where((table) => table.status.equalsValue(status));
    }
    final normalizedSearch = search.trim();
    if (normalizedSearch.isNotEmpty) {
      final pattern = '%$normalizedSearch%';
      query.where(
        (table) =>
            table.name.like(pattern) |
            table.vehicleNo.like(pattern) |
            table.licensePlate.like(pattern) |
            table.workArea.like(pattern) |
            table.responsiblePerson.like(pattern),
      );
    }
    return query.watch();
  }

  Future<Vehicle?> findById(int id) {
    return (_database.select(
      _database.vehicles,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<Vehicle> save({int? id, required VehicleDraft draft}) async {
    final name = draft.name.trim();
    final vehicleNo = draft.vehicleNo.trim();
    if (name.isEmpty) throw ArgumentError('车辆名称不能为空');
    if (vehicleNo.isEmpty) throw ArgumentError('车辆编号不能为空');
    final now = DateTime.now();
    final values = VehiclesCompanion(
      name: Value(name),
      vehicleNo: Value(vehicleNo),
      licensePlate: Value(_nullable(draft.licensePlate)),
      vehicleType: Value(draft.vehicleType),
      brand: Value(_nullable(draft.brand)),
      model: Value(_nullable(draft.model)),
      purchaseDate: Value(draft.purchaseDate),
      department: Value(_nullable(draft.department)),
      workArea: Value(_nullable(draft.workArea)),
      responsiblePerson: Value(_nullable(draft.responsiblePerson)),
      status: Value(draft.status),
      remark: Value(_nullable(draft.remark)),
      updatedAt: Value(now),
      isDeleted: const Value(false),
    );
    late final int vehicleId;
    if (id == null) {
      vehicleId = await _database
          .into(_database.vehicles)
          .insert(
            VehiclesCompanion.insert(
              name: name,
              vehicleNo: vehicleNo,
              licensePlate: Value(_nullable(draft.licensePlate)),
              vehicleType: Value(draft.vehicleType),
              brand: Value(_nullable(draft.brand)),
              model: Value(_nullable(draft.model)),
              purchaseDate: Value(draft.purchaseDate),
              department: Value(_nullable(draft.department)),
              workArea: Value(_nullable(draft.workArea)),
              responsiblePerson: Value(_nullable(draft.responsiblePerson)),
              status: Value(draft.status),
              remark: Value(_nullable(draft.remark)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } else {
      final existing = await findById(id);
      if (existing == null) throw StateError('车辆不存在');
      await (_database.update(
        _database.vehicles,
      )..where((table) => table.id.equals(id))).write(values);
      vehicleId = id;
    }
    final vehicle = await findById(vehicleId);
    if (vehicle == null) throw StateError('车辆保存后无法读取');
    return vehicle;
  }

  Future<int> softDelete(int id) {
    return (_database.update(
      _database.vehicles,
    )..where((table) => table.id.equals(id))).write(
      VehiclesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> setStatus(int id, VehicleStatus status) {
    return (_database.update(
      _database.vehicles,
    )..where((table) => table.id.equals(id))).write(
      VehiclesCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restore(int id) {
    return (_database.update(
      _database.vehicles,
    )..where((table) => table.id.equals(id))).write(
      VehiclesCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
