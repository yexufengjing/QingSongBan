import '../../../core/database/app_database.dart';

class PayrollCandidate {
  const PayrollCandidate({
    required this.employee,
    required this.attendanceHalfDays,
    required this.summaryId,
  });

  final Employee employee;
  final int attendanceHalfDays;
  final int summaryId;
}

class PayrollValidationIssue {
  const PayrollValidationIssue({
    required this.message,
    this.employeeId,
    this.code = 'payroll',
  });

  final String code;
  final int? employeeId;
  final String message;
}

class PayrollValidationResult {
  const PayrollValidationResult({required this.errors, required this.warnings});

  final List<PayrollValidationIssue> errors;
  final List<PayrollValidationIssue> warnings;

  bool get canConfirm => errors.isEmpty;
}

class PayrollItemWithEmployee {
  const PayrollItemWithEmployee({required this.item, required this.employee});

  final PayrollItem item;
  final Employee? employee;
}

class PayrollHistoryEntry {
  const PayrollHistoryEntry({required this.batch, required this.item});

  final PayrollBatche batch;
  final PayrollItem item;
}
