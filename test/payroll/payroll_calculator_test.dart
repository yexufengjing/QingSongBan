import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/payroll/domain/payroll_calculator.dart';

void main() {
  test('calculates half-day payroll and rounds to two decimals', () {
    final result = PayrollCalculator.calculate(
      attendanceHalfDays: 49,
      dailyWage: 120,
      subsidy: 300,
      insuranceDeduction: 150,
    );

    expect(result.attendanceDays, 24.5);
    expect(result.baseWage, 2940.00);
    expect(result.finalWage, 3090.00);
    expect(result.insuranceExceedsAvailable, isFalse);
  });

  test('clamps a negative final wage to zero and reports the warning', () {
    final result = PayrollCalculator.calculate(
      attendanceHalfDays: 1,
      dailyWage: 100,
      subsidy: 0,
      insuranceDeduction: 200,
    );

    expect(result.preFloorFinalWage, -150.00);
    expect(result.finalWage, 0.00);
    expect(result.insuranceExceedsAvailable, isTrue);
  });
}
