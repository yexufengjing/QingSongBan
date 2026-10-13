import '../../../core/database/app_database.dart';
import 'payroll_calculator.dart';

/// The export contract shared by Excel and the complete image preview.
class PayrollExportSnapshot {
  PayrollExportSnapshot.fromBatch(PayrollBatche batch, List<PayrollItem> items)
    : batchId = batch.id,
      payrollMonth = batch.payrollMonth,
      batchName = batch.name,
      rows = List.unmodifiable([
        for (var index = 0; index < items.length; index++)
          List<Object>.unmodifiable(_itemRow(items[index], index + 1)),
      ]),
      totalRow = List<Object>.unmodifiable([
        '合计',
        '${batch.employeeCount}人',
        '',
        '',
        batch.attendanceHalfDaysTotal / 2,
        '',
        batch.baseWageTotal,
        batch.subsidyTotal,
        batch.insuranceDeductionTotal,
        batch.finalWageTotal,
        '',
      ]);

  static const headers = [
    '序号',
    '姓名',
    '工号',
    '工种',
    '出勤天数',
    '日薪',
    '基础工资',
    '补助',
    '保险扣除',
    '实发工资',
    '备注',
  ];
  final int batchId;
  final String payrollMonth;
  final String batchName;
  final List<List<Object>> rows;
  final List<Object> totalRow;

  static List<Object> _itemRow(PayrollItem item, int index) {
    final calculation = PayrollCalculator.calculate(
      attendanceHalfDays: item.attendanceHalfDaysSnapshot,
      dailyWage: item.dailyWage,
      subsidy: item.subsidy,
      insuranceDeduction: item.insuranceDeduction,
    );
    return [
      index,
      item.employeeNameSnapshot,
      item.employeeNoSnapshot,
      item.jobTypeNameSnapshot ?? '',
      calculation.attendanceDays,
      item.dailyWage,
      calculation.baseWage,
      item.subsidy,
      item.insuranceDeduction,
      calculation.finalWage,
      item.remark ?? '',
    ];
  }

  static String formatCell(Object value, int column) {
    if (value is num && column == 4) return value.toStringAsFixed(1);
    if (value is num && column >= 5 && column <= 9) {
      return PayrollCalculator.roundMoney(value.toDouble()).toStringAsFixed(2);
    }
    return value.toString();
  }
}
