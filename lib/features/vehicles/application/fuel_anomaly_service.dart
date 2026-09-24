import '../../../core/database/app_database.dart';
import '../data/fuel_repository.dart';

class FuelAnomaly {
  const FuelAnomaly({
    required this.vehicleId,
    required this.year,
    required this.month,
    required this.highComparedWithRecentAverage,
    required this.consecutiveIncrease,
    required this.message,
  });

  final int vehicleId;
  final int year;
  final int month;
  final bool highComparedWithRecentAverage;
  final bool consecutiveIncrease;
  final String message;

  bool get hasWarning => highComparedWithRecentAverage || consecutiveIncrease;
}

class FuelAnomalyService {
  const FuelAnomalyService(this._repository);

  final FuelRepository _repository;

  Future<FuelAnomaly?> analyze({
    required int vehicleId,
    required int year,
    required int month,
  }) async {
    final rows = await _repository.listByVehicle(vehicleId, year);
    final index = rows.indexWhere((row) => row.month == month);
    if (index < 0) return null;
    final current = rows[index];
    final recent = rows
        .where((row) => row.month < month && row.month >= month - 3)
        .toList();
    final average = recent.isEmpty
        ? null
        : recent.fold<double>(0, (sum, row) => sum + row.liters) /
              recent.length;
    final high =
        average != null && average > 0 && current.liters > average * 1.25;
    final increasing = _isConsecutiveIncrease(rows, index);
    final messages = <String>[];
    if (high) messages.add('本月油耗高于近3月均值25%以上');
    if (increasing) messages.add('油耗已连续3个月上升');
    return FuelAnomaly(
      vehicleId: vehicleId,
      year: year,
      month: month,
      highComparedWithRecentAverage: high,
      consecutiveIncrease: increasing,
      message: messages.isEmpty ? '油耗正常' : messages.join('；'),
    );
  }

  bool _isConsecutiveIncrease(List<FuelMonthlyRecord> rows, int index) {
    if (index < 2) return false;
    final a = rows[index - 2];
    final b = rows[index - 1];
    final c = rows[index];
    if (b.month - a.month != 1 || c.month - b.month != 1) return false;
    return a.liters < b.liters && b.liters < c.liters;
  }
}
