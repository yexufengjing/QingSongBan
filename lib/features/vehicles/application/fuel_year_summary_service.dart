import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../domain/fuel_year_summary_options.dart';

class FuelYearSummaryService {
  const FuelYearSummaryService(this._database);

  final AppDatabase _database;

  Future<FuelYearSummary> build(int year) async {
    final vehicles = await (_database.select(
      _database.vehicles,
    )..where((table) => table.isDeleted.equals(false))).get();
    final rows =
        await (_database.select(_database.fuelMonthlyRecords)..where(
              (table) =>
                  table.year.equals(year) & table.isDeleted.equals(false),
            ))
            .get();
    final rowsByVehicle = <int, Map<int, FuelMonthlyRecord>>{};
    for (final row in rows) {
      rowsByVehicle.putIfAbsent(row.vehicleId, () => {})[row.month] = row;
    }

    final included =
        vehicles
            .where(
              (vehicle) =>
                  rowsByVehicle.containsKey(vehicle.id) ||
                  _isActive(vehicle.status),
            )
            .toList()
          ..sort((a, b) {
            final number = a.vehicleNo.compareTo(b.vehicleNo);
            return number == 0 ? a.name.compareTo(b.name) : number;
          });

    final vehicleSummaries = [
      for (final vehicle in included)
        FuelVehicleSummary(
          vehicle: vehicle,
          recordsByMonth: {
            for (var month = 1; month <= 12; month++)
              month: rowsByVehicle[vehicle.id]?[month],
          },
        ),
    ];
    final monthSummaries = [
      for (var month = 1; month <= 12; month++)
        _buildMonthSummary(month, vehicleSummaries),
    ];
    final expectedMonths = year == DateTime.now().year
        ? DateTime.now().month
        : 12;
    final expectedRecordCount = included.length * expectedMonths;
    final missing = <FuelMissingRecord>[];
    for (final vehicle in vehicleSummaries) {
      for (var month = 1; month <= expectedMonths; month++) {
        if (vehicle.recordsByMonth[month] == null) {
          missing.add(
            FuelMissingRecord(
              vehicleId: vehicle.vehicle.id,
              vehicleNo: vehicle.vehicle.vehicleNo,
              vehicleName: vehicle.vehicle.name,
              month: month,
            ),
          );
        }
      }
    }
    return FuelYearSummary(
      year: year,
      vehicles: vehicleSummaries,
      months: monthSummaries,
      expectedRecordCount: expectedRecordCount,
      actualRecordCount: rows.length,
      missingRecords: missing,
      anomalies: _buildAnomalies(vehicleSummaries),
    );
  }

  FuelMonthSummary _buildMonthSummary(
    int month,
    List<FuelVehicleSummary> vehicles,
  ) {
    final records = [
      for (final vehicle in vehicles) vehicle.recordsByMonth[month],
    ].whereType<FuelMonthlyRecord>().toList();
    final totalLiters = records.fold<double>(
      0,
      (sum, record) => sum + record.liters,
    );
    final totalAmountCents = records.fold<int>(
      0,
      (sum, record) => sum + record.amountCents,
    );
    return FuelMonthSummary(
      month: month,
      totalLiters: totalLiters,
      totalAmountCents: totalAmountCents,
      validVehicleCount: records.length,
      averageLiters: records.isEmpty ? 0 : totalLiters / records.length,
      averageAmountCents: records.isEmpty
          ? 0
          : (totalAmountCents / records.length).round(),
    );
  }

  List<FuelSummaryAnomaly> _buildAnomalies(List<FuelVehicleSummary> vehicles) {
    final result = <FuelSummaryAnomaly>[];
    for (final vehicle in vehicles) {
      final rows = [
        for (var month = 1; month <= 12; month++) vehicle.recordsByMonth[month],
      ].whereType<FuelMonthlyRecord>().toList();
      for (var index = 0; index < rows.length; index++) {
        final current = rows[index];
        final previous = index == 0 ? null : rows[index - 1];
        final change = previous == null || previous.liters == 0
            ? null
            : (current.liters - previous.liters) / previous.liters * 100;
        final recent = rows
            .where(
              (row) =>
                  row.month < current.month && row.month >= current.month - 3,
            )
            .toList();
        final average = recent.isEmpty
            ? null
            : recent.fold<double>(0, (sum, row) => sum + row.liters) /
                  recent.length;
        final high =
            average != null && average > 0 && current.liters > average * 1.25;
        final increasing =
            index >= 2 &&
            rows[index - 2].month + 1 == rows[index - 1].month &&
            rows[index - 1].month + 1 == current.month &&
            rows[index - 2].liters < rows[index - 1].liters &&
            rows[index - 1].liters < current.liters;
        if (high || increasing) {
          result.add(
            FuelSummaryAnomaly(
              vehicleId: vehicle.vehicle.id,
              vehicleName: vehicle.vehicle.name,
              month: current.month,
              changePercent: change,
              message: [
                if (high) '高于近3个有效月份平均值25%',
                if (increasing) '连续3个月上升',
              ].join('；'),
            ),
          );
        }
      }
    }
    return result;
  }

  bool _isActive(VehicleStatus status) => switch (status) {
    VehicleStatus.normal ||
    VehicleStatus.pendingRepair ||
    VehicleStatus.repairing => true,
    VehicleStatus.stopped || VehicleStatus.scrapped => false,
  };
}
