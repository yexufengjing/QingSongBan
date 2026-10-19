import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../domain/assistant_models.dart';

/// Read-only, aggregate-only adapter for the vehicle expense agent.
///
/// It deliberately returns no row identifiers, plate numbers, remarks, repair
/// symptoms, or other free text.
class AssistantVehicleExpenseReader implements VehicleExpenseReadPort {
  AssistantVehicleExpenseReader(this._database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _clock;

  @override
  Future<VehicleExpensePeriodResult> readVehicleExpenses(
    VehicleExpenseToolRequest request,
  ) async {
    final period = _resolvePeriod(request.period, yearMonth: request.yearMonth);
    return _readPeriod(
      request.vehicleId,
      period.start,
      period.end,
      request.scope,
    );
  }

  @override
  Future<VehicleExpensePeerResult> comparePeerVehicleExpenses(
    VehicleExpenseToolRequest request,
  ) async {
    final target =
        await (_database.select(_database.vehicles)..where(
              (table) =>
                  table.id.equals(request.vehicleId) &
                  table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (target == null) {
      throw const AssistantProviderException(
        AssistantErrorCode.entityUnavailable,
      );
    }

    final period = _resolvePeriod(request.period, yearMonth: request.yearMonth);
    final candidates =
        await (_database.select(_database.vehicles)..where(
              (table) =>
                  table.isDeleted.equals(false) &
                  table.id.isNotValue(request.vehicleId) &
                  table.vehicleType.equalsValue(target.vehicleType) &
                  table.brand.equalsNullable(target.brand) &
                  table.model.equalsNullable(target.model),
            ))
            .get();

    final peerResults = <VehicleExpensePeriodResult>[];
    for (final candidate in candidates) {
      peerResults.add(
        await _readPeriod(
          candidate.id,
          period.start,
          period.end,
          request.scope,
        ),
      );
    }
    final own = await _readPeriod(
      request.vehicleId,
      period.start,
      period.end,
      request.scope,
    );

    final targetCategory = _categoryFor(own, request.scope);
    final registeredPeers = peerResults
        .where((result) => _hasComparableExpense(result, request.scope))
        .toList();
    final missingPeerCount = candidates.length - registeredPeers.length;
    final peerAmount = registeredPeers.isEmpty
        ? null
        : (registeredPeers.fold<int>(
                    0,
                    (sum, result) =>
                        sum + _categoryFor(result, request.scope)!.amountCents,
                  ) /
                  registeredPeers.length)
              .round();

    final targetWorkload = own.workload;
    final peerWorkload = _averageWorkload(
      registeredPeers,
      registeredPeerCount: registeredPeers.length,
      totalCandidateCount: candidates.length,
    );
    final targetAmount = targetCategory?.recordCount == 0
        ? null
        : targetCategory?.amountCents;
    final hasTargetRegistration =
        targetCategory != null && targetCategory.recordCount > 0;
    final alignedNaturalMonth = _isMonthAlignedRange(period.start, period.end);
    final metricComparison = alignedNaturalMonth
        ? _unitCostComparison(own, registeredPeers, request.scope)
        : null;
    final targetCentsPerKilometer =
        metricComparison?.metricUnit == VehicleExpenseWorkloadMetric.mileage
        ? metricComparison?.targetUnitCost
        : null;
    final peerMeanCentsPerKilometer =
        metricComparison?.metricUnit == VehicleExpenseWorkloadMetric.mileage
        ? metricComparison?.peerUnitCost
        : null;
    final allPeersRegistered = candidates.isNotEmpty && missingPeerCount == 0;
    final hasAnyPeerData = registeredPeers.isNotEmpty;
    final metricMissing =
        alignedNaturalMonth &&
        hasTargetRegistration &&
        hasAnyPeerData &&
        metricComparison?.peerUnitCost == null;
    final selectedMetric = metricComparison?.metricUnit;
    final metricCoveragePartial =
        metricComparison != null &&
        metricComparison.peerVehicleCount < registeredPeers.length;
    final comparability = !hasTargetRegistration || !hasAnyPeerData
        ? VehicleExpenseCoverage.unknown
        : allPeersRegistered && !metricMissing && !metricCoveragePartial
        ? VehicleExpenseCoverage.complete
        : VehicleExpenseCoverage.partial;

    final notes = <String>[
      if (registeredPeers.isNotEmpty)
        '同车型、品牌和型号中，纳入 ${registeredPeers.length} 辆有同期费用记录的车辆；'
            '其余 $missingPeerCount 辆没有可比登记，不按零费用计入均值。',
      if (registeredPeers.isEmpty)
        candidates.isEmpty
            ? '没有找到车型、品牌和型号一致的其他车辆。'
            : '找到 ${candidates.length} 辆相同车型车辆，但都没有该期间的可比登记记录；'
                  '未将无记录当作零费用。',
      if (request.scope == VehicleExpenseCategoryScope.all &&
          own.coverageNotes.any((note) => note.contains('月度油费')))
        '金额均值只含与所选期间对齐的费用记录；交叠月份油费单独展示。',
      if (selectedMetric != null)
        '单位成本按同一自然月的费用和工作量计算；采用'
            '${_metricLabel(selectedMetric)}。台账登记完整性仍未知。',
      if (metricCoveragePartial) '单位成本仅纳入具备该同期工作量指标的同类车辆；其余车辆不按缺失指标估算。',
      if (metricMissing) '费用金额仍可作同月参考；目标车或同类车辆没有可共同使用的同期工作量指标。',
      if (!alignedNaturalMonth) '当前期间不是完整自然月，仅提供同期间金额参考；不把月度工作量套到日级费用。',
    ];

    return VehicleExpensePeerResult(
      period: own,
      category: request.scope,
      comparableVehicleCount: registeredPeers.length,
      peerAmountCents: peerAmount,
      targetAmountCents: targetAmount,
      comparability: comparability,
      targetWorkload: targetWorkload,
      peerWorkload: peerWorkload,
      targetCentsPerKilometer: targetCentsPerKilometer,
      peerMeanCentsPerKilometer: peerMeanCentsPerKilometer,
      metricUnit: metricComparison?.metricUnit,
      targetUnitCost: metricComparison?.targetUnitCost,
      peerUnitCost: metricComparison?.peerUnitCost,
      note: notes.join(' '),
    );
  }

  Future<VehicleExpensePeriodResult> _readPeriod(
    int vehicleId,
    DateTime start,
    DateTime end,
    VehicleExpenseCategoryScope scope,
  ) async {
    final includeRepair =
        scope == VehicleExpenseCategoryScope.all ||
        scope == VehicleExpenseCategoryScope.repair;
    final includeMaintenance =
        scope == VehicleExpenseCategoryScope.all ||
        scope == VehicleExpenseCategoryScope.maintenance;
    final includeManual =
        scope == VehicleExpenseCategoryScope.all ||
        scope == VehicleExpenseCategoryScope.manual;
    final includeFuel =
        scope == VehicleExpenseCategoryScope.all ||
        scope == VehicleExpenseCategoryScope.fuel;
    final alignedMonthRange = _isMonthAlignedRange(start, end);
    final readFuelForWorkload = includeFuel || alignedMonthRange;
    final includeFuelInCategories =
        scope == VehicleExpenseCategoryScope.fuel ||
        (scope == VehicleExpenseCategoryScope.all && alignedMonthRange);

    final repairs = includeRepair
        ? await (_database.select(_database.repairOrders)..where(
                (table) =>
                    table.vehicleId.equals(vehicleId) &
                    table.status.equalsValue(VehicleRepairStatus.completed) &
                    table.isDeleted.equals(false),
              ))
              .get()
        : <RepairOrder>[];
    final maintenance = includeMaintenance
        ? await (_database.select(_database.maintenanceRecords)..where(
                (table) =>
                    table.vehicleId.equals(vehicleId) &
                    table.isDeleted.equals(false),
              ))
              .get()
        : <MaintenanceRecord>[];
    final manual = includeManual
        ? await (_database.select(_database.manualVehicleExpenses)..where(
                (table) =>
                    table.vehicleId.equals(vehicleId) &
                    table.isDeleted.equals(false),
              ))
              .get()
        : <ManualVehicleExpense>[];
    final fuelRecords = readFuelForWorkload
        ? await (_database.select(_database.fuelMonthlyRecords)..where(
                (table) =>
                    table.vehicleId.equals(vehicleId) &
                    table.isDeleted.equals(false),
              ))
              .get()
        : <FuelMonthlyRecord>[];

    final repairRows = repairs
        .where((row) => _contains(start, end, row.reportDate))
        .toList();
    final maintenanceRows = maintenance
        .where((row) => _contains(start, end, row.serviceDate))
        .toList();
    final manualRows = manual
        .where((row) => _contains(start, end, row.expenseDate))
        .toList();

    final overlappingFuel = <FuelMonthlyRecord>[];
    final fullyContainedFuel = <FuelMonthlyRecord>[];
    final hasPartialFuelMonth = <FuelMonthlyRecord>[];
    for (final record in fuelRecords) {
      final monthStart = DateTime(record.year, record.month);
      final monthEnd = DateTime(record.year, record.month + 1);
      if (!monthStart.isBefore(end) || !monthEnd.isAfter(start)) continue;
      overlappingFuel.add(record);
      if (!monthStart.isBefore(start) && !monthEnd.isAfter(end)) {
        fullyContainedFuel.add(record);
      } else {
        hasPartialFuelMonth.add(record);
      }
    }

    final fuelMonths =
        !includeFuel
              ? <VehicleFuelMonthResult>[]
              : [
                  for (final fuel in overlappingFuel)
                    VehicleFuelMonthResult(
                      year: fuel.year,
                      month: fuel.month,
                      amountCents: fuel.amountCents,
                      liters: fuel.liters,
                      workDays: fuel.workDays,
                      mileage: fuel.workMileage,
                      workHours: fuel.workHours,
                      coverage: _fuelMonthCoverage(fuel.year, fuel.month),
                    ),
                ]
          ..sort((a, b) {
            final byYear = a.year.compareTo(b.year);
            return byYear == 0 ? a.month.compareTo(b.month) : byYear;
          });

    final repairAmount = repairRows.fold<int>(
      0,
      (sum, row) => sum + row.actualAmountCents,
    );
    final maintenanceAmount = maintenanceRows.fold<int>(
      0,
      (sum, row) => sum + row.totalCostCents,
    );
    final manualAmount = manualRows.fold<int>(
      0,
      (sum, row) => sum + row.amountCents,
    );
    final fuelAmount = fullyContainedFuel.fold<int>(
      0,
      (sum, row) => sum + row.amountCents,
    );
    final missingContainedFuelMonth =
        includeFuelInCategories &&
        _containedMonthCount(start, end) > fullyContainedFuel.length;
    final fuelCoverage =
        hasPartialFuelMonth.isNotEmpty || missingContainedFuelMonth
        ? VehicleExpenseCoverage.partial
        : VehicleExpenseCoverage.unknown;

    final categories = <VehicleExpenseCategoryResult>[];
    if (includeRepair) {
      categories.add(
        _category(
          VehicleExpenseCategoryScope.repair,
          repairAmount,
          repairRows.length,
        ),
      );
    }
    if (includeMaintenance) {
      categories.add(
        _category(
          VehicleExpenseCategoryScope.maintenance,
          maintenanceAmount,
          maintenanceRows.length,
        ),
      );
    }
    if (includeManual) {
      categories.add(
        _category(
          VehicleExpenseCategoryScope.manual,
          manualAmount,
          manualRows.length,
        ),
      );
    }
    if (includeFuelInCategories) {
      categories.add(
        _category(
          VehicleExpenseCategoryScope.fuel,
          fuelAmount,
          fullyContainedFuel.length,
          coverage: fuelCoverage,
        ),
      );
    }
    if (scope == VehicleExpenseCategoryScope.all) {
      categories.add(
        _category(
          VehicleExpenseCategoryScope.all,
          repairAmount +
              maintenanceAmount +
              manualAmount +
              (alignedMonthRange ? fuelAmount : 0),
          repairRows.length +
              maintenanceRows.length +
              manualRows.length +
              (alignedMonthRange ? fullyContainedFuel.length : 0),
          coverage: hasPartialFuelMonth.isNotEmpty || missingContainedFuelMonth
              ? VehicleExpenseCoverage.partial
              : VehicleExpenseCoverage.unknown,
        ),
      );
    }

    final workloadPeriodAligned =
        scope == VehicleExpenseCategoryScope.fuel || alignedMonthRange;
    final workload = workloadPeriodAligned
        ? _periodWorkload(
            fullyContainedFuel,
            expectedMonthCount: _containedMonthCount(start, end),
          )
        : null;
    final notes = <String>[
      '维修按已完成、未删除维修单的报修日期和实际金额统计。',
      '保养按执行日期、手工费用按费用日期统计。',
      '日级费用没有完整登记标记；没有记录不代表零支出。',
      if (includeFuel) '油费按月记录；非自然月期间不纳入日级合计，重叠月份单独列示。',
      if (includeFuel && overlappingFuel.isEmpty)
        '该期间没有已登记的重叠月份油费记录；这不代表实际油费为零。',
      if (includeFuelInCategories &&
          _containedMonthCount(start, end) > fullyContainedFuel.length)
        '所选期间有 ${_containedMonthCount(start, end) - fullyContainedFuel.length} '
            '个月份没有油费登记，不按零费用纳入合计。',
      if (!includeFuel && alignedMonthRange && workload != null)
        '同期工作量取自当月工作量登记；油费金额和油量未包含在本次费用类别结果中。',
    ];

    return VehicleExpensePeriodResult(
      startInclusive: start,
      endExclusive: end,
      granularity: scope == VehicleExpenseCategoryScope.fuel
          ? VehicleExpenseGranularity.monthly
          : VehicleExpenseGranularity.daily,
      coverage: hasPartialFuelMonth.isNotEmpty || missingContainedFuelMonth
          ? VehicleExpenseCoverage.partial
          : VehicleExpenseCoverage.unknown,
      categories: categories,
      fuelMonths: fuelMonths,
      workload: workload,
      coverageNotes: notes,
    );
  }

  VehicleExpenseWorkload? _periodWorkload(
    List<FuelMonthlyRecord> records, {
    required int expectedMonthCount,
  }) {
    if (expectedMonthCount == 0) return null;
    if (records.length != expectedMonthCount) {
      return VehicleExpenseWorkload(coverage: VehicleExpenseCoverage.partial);
    }
    final mileage = _sumCompleteDoubleMetric(
      records,
      (record) => record.workMileage,
    );
    final workDays = _sumCompleteIntMetric(
      records,
      (record) => record.workDays,
    );
    final workHours = _sumCompleteDoubleMetric(
      records,
      (record) => record.workHours,
    );
    if (mileage == null && workDays == null && workHours == null) {
      return VehicleExpenseWorkload(coverage: VehicleExpenseCoverage.unknown);
    }
    return VehicleExpenseWorkload(
      mileage: mileage,
      workDays: workDays,
      workHours: workHours,
      coverage: mileage != null && workDays != null && workHours != null
          ? VehicleExpenseCoverage.complete
          : VehicleExpenseCoverage.partial,
    );
  }

  double? _sumCompleteDoubleMetric(
    List<FuelMonthlyRecord> records,
    double? Function(FuelMonthlyRecord record) read,
  ) {
    final values = records.map(read).toList();
    if (values.isEmpty || values.any((value) => value == null)) return null;
    return values.fold<double>(0, (sum, value) => sum + value!);
  }

  int? _sumCompleteIntMetric(
    List<FuelMonthlyRecord> records,
    int? Function(FuelMonthlyRecord record) read,
  ) {
    final values = records.map(read).toList();
    if (values.isEmpty || values.any((value) => value == null)) return null;
    return values.fold<int>(0, (sum, value) => sum + value!);
  }

  VehicleExpenseWorkload? _averageWorkload(
    List<VehicleExpensePeriodResult> peers, {
    required int registeredPeerCount,
    required int totalCandidateCount,
  }) {
    if (peers.isEmpty) return null;
    final mileageValues = peers
        .map((peer) => peer.workload?.mileage)
        .whereType<double>()
        .toList();
    final daysValues = peers
        .map((peer) => peer.workload?.workDays)
        .whereType<int>()
        .toList();
    final hoursValues = peers
        .map((peer) => peer.workload?.workHours)
        .whereType<double>()
        .toList();
    if (mileageValues.isEmpty && daysValues.isEmpty && hoursValues.isEmpty) {
      return VehicleExpenseWorkload(coverage: VehicleExpenseCoverage.unknown);
    }
    final allHaveAllMetrics =
        mileageValues.length == registeredPeerCount &&
        daysValues.length == registeredPeerCount &&
        hoursValues.length == registeredPeerCount &&
        registeredPeerCount == totalCandidateCount;
    return VehicleExpenseWorkload(
      mileage: _average(mileageValues),
      workDays: _averageInt(daysValues),
      workHours: _average(hoursValues),
      coverage: allHaveAllMetrics
          ? VehicleExpenseCoverage.complete
          : VehicleExpenseCoverage.partial,
    );
  }

  double? _average(List<double> values) => values.isEmpty
      ? null
      : values.reduce((left, right) => left + right) / values.length;

  int? _averageInt(List<int> values) => values.isEmpty
      ? null
      : (values.reduce((left, right) => left + right) / values.length).round();

  ({
    VehicleExpenseWorkloadMetric metricUnit,
    double targetUnitCost,
    double? peerUnitCost,
    int peerVehicleCount,
  })?
  _unitCostComparison(
    VehicleExpensePeriodResult target,
    List<VehicleExpensePeriodResult> peers,
    VehicleExpenseCategoryScope scope,
  ) {
    final targetAmount = _categoryFor(target, scope);
    if (targetAmount == null || targetAmount.recordCount == 0) return null;
    for (final metric in VehicleExpenseWorkloadMetric.values) {
      final targetValue = _workloadValue(target.workload, metric);
      if (targetValue == null || targetValue <= 0) continue;
      final peersWithMetric = peers.where((peer) {
        final category = _categoryFor(peer, scope);
        final value = _workloadValue(peer.workload, metric);
        return category != null &&
            category.recordCount > 0 &&
            value != null &&
            value > 0;
      }).toList();
      if (peersWithMetric.isEmpty) {
        return (
          metricUnit: metric,
          targetUnitCost: targetAmount.amountCents / targetValue,
          peerUnitCost: null,
          peerVehicleCount: 0,
        );
      }
      final peerAmount = peersWithMetric.fold<int>(
        0,
        (sum, peer) => sum + _categoryFor(peer, scope)!.amountCents,
      );
      final peerWorkload = peersWithMetric.fold<double>(
        0,
        (sum, peer) => sum + _workloadValue(peer.workload, metric)!,
      );
      return (
        metricUnit: metric,
        targetUnitCost: targetAmount.amountCents / targetValue,
        peerUnitCost: peerAmount / peerWorkload,
        peerVehicleCount: peersWithMetric.length,
      );
    }
    return null;
  }

  double? _workloadValue(
    VehicleExpenseWorkload? workload,
    VehicleExpenseWorkloadMetric metric,
  ) => switch (metric) {
    VehicleExpenseWorkloadMetric.mileage => workload?.mileage,
    VehicleExpenseWorkloadMetric.workHours => workload?.workHours,
    VehicleExpenseWorkloadMetric.workDays => workload?.workDays?.toDouble(),
  };

  String _metricLabel(VehicleExpenseWorkloadMetric metric) => switch (metric) {
    VehicleExpenseWorkloadMetric.mileage => '元/公里',
    VehicleExpenseWorkloadMetric.workHours => '元/工时',
    VehicleExpenseWorkloadMetric.workDays => '元/工作日',
  };

  bool _isMonthAlignedRange(DateTime start, DateTime end) =>
      start.day == 1 && end.day == 1 && start.isBefore(end);

  int _containedMonthCount(DateTime start, DateTime end) {
    var month = DateTime(start.year, start.month);
    if (month.isBefore(start)) month = DateTime(month.year, month.month + 1);
    var count = 0;
    while (month.isBefore(end)) {
      final next = DateTime(month.year, month.month + 1);
      if (!month.isBefore(start) && !next.isAfter(end)) count++;
      month = next;
    }
    return count;
  }

  VehicleExpenseCategoryResult? _categoryFor(
    VehicleExpensePeriodResult result,
    VehicleExpenseCategoryScope scope,
  ) => result.categories.where((item) => item.category == scope).firstOrNull;

  bool _hasComparableExpense(
    VehicleExpensePeriodResult result,
    VehicleExpenseCategoryScope scope,
  ) {
    final category = _categoryFor(result, scope);
    return category != null && category.recordCount > 0;
  }

  VehicleExpenseCategoryResult _category(
    VehicleExpenseCategoryScope category,
    int amountCents,
    int count, {
    VehicleExpenseCoverage coverage = VehicleExpenseCoverage.unknown,
  }) => VehicleExpenseCategoryResult(
    category: category,
    amountCents: amountCents,
    recordCount: count,
    coverage: coverage,
  );

  VehicleExpenseCoverage _fuelMonthCoverage(int year, int month) {
    final today = _dateOnly(_clock());
    final monthStart = DateTime(year, month);
    final monthEnd = DateTime(year, month + 1);
    return !today.isBefore(monthStart) && today.isBefore(monthEnd)
        ? VehicleExpenseCoverage.partial
        : VehicleExpenseCoverage.unknown;
  }

  ({DateTime start, DateTime end}) _resolvePeriod(
    AssistantAgentPeriod period, {
    String? yearMonth,
  }) {
    if (yearMonth != null) {
      final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(yearMonth);
      if (match == null) {
        throw const AssistantProviderException(
          AssistantErrorCode.invalidArgument,
        );
      }
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      return (start: DateTime(year, month), end: DateTime(year, month + 1));
    }
    final now = _dateOnly(_clock());
    final tomorrow = now.add(const Duration(days: 1));
    return switch (period) {
      AssistantAgentPeriod.recent30Days => (
        start: tomorrow.subtract(const Duration(days: 30)),
        end: tomorrow,
      ),
      AssistantAgentPeriod.previous30Days => (
        start: tomorrow.subtract(const Duration(days: 60)),
        end: tomorrow.subtract(const Duration(days: 30)),
      ),
      AssistantAgentPeriod.recent90Days => (
        start: tomorrow.subtract(const Duration(days: 90)),
        end: tomorrow,
      ),
      AssistantAgentPeriod.previousMonth => (
        start: DateTime(now.year, now.month - 1),
        end: DateTime(now.year, now.month),
      ),
    };
  }

  bool _contains(DateTime start, DateTime end, DateTime value) {
    final date = _dateOnly(value);
    return !date.isBefore(start) && date.isBefore(end);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
