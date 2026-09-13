class PayrollCalculation {
  const PayrollCalculation({
    required this.attendanceDays,
    required this.baseWage,
    required this.preFloorFinalWage,
    required this.finalWage,
    required this.insuranceExceedsAvailable,
  });

  final double attendanceDays;
  final double baseWage;
  final double preFloorFinalWage;
  final double finalWage;
  final bool insuranceExceedsAvailable;
}

abstract final class PayrollCalculator {
  static PayrollCalculation calculate({
    required int attendanceHalfDays,
    required double dailyWage,
    required double subsidy,
    required double insuranceDeduction,
  }) {
    _requireFiniteNonNegative('attendanceHalfDays', attendanceHalfDays);
    _requireFiniteNonNegative('dailyWage', dailyWage);
    _requireFiniteNonNegative('subsidy', subsidy);
    _requireFiniteNonNegative('insuranceDeduction', insuranceDeduction);

    final baseWage = roundMoney(attendanceHalfDays / 2 * dailyWage);
    final preFloorFinalWage = roundMoney(
      baseWage + subsidy - insuranceDeduction,
    );
    return PayrollCalculation(
      attendanceDays: attendanceHalfDays / 2,
      baseWage: baseWage,
      preFloorFinalWage: preFloorFinalWage,
      finalWage: preFloorFinalWage < 0 ? 0 : preFloorFinalWage,
      insuranceExceedsAvailable:
          insuranceDeduction > roundMoney(baseWage + subsidy),
    );
  }

  static double roundMoney(double value) {
    if (!value.isFinite) throw const FormatException('金额必须是有效数字');
    return (value * 100).roundToDouble() / 100;
  }

  static void _requireFiniteNonNegative(String field, num value) {
    if (value is double && !value.isFinite || value < 0) {
      throw FormatException('$field 必须是大于等于 0 的有效数字');
    }
  }
}
