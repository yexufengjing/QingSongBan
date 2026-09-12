import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';

abstract final class TerminationOptions {
  static const types = <String>[
    'personal',
    'contractEnded',
    'companyInitiated',
    'other',
  ];

  static String typeLabel(String type) {
    return switch (type) {
      'personal' => '个人原因',
      'contractEnded' => '合同到期',
      'companyInitiated' => '单位安排',
      _ => '其他',
    };
  }
}

class TerminationRecordView {
  const TerminationRecordView({
    required this.termination,
    required this.employee,
  });

  final TerminationRecord termination;
  final Employee employee;
}

class TerminationRecordDraft {
  const TerminationRecordDraft({
    required this.employeeId,
    required this.terminationDate,
    required this.terminationType,
    required this.isInsuranceStopped,
    required this.toolsReturned,
    required this.materialsTransferred,
    required this.hasUnsettledItems,
    this.stopInsuranceMonth,
    this.remark,
  });

  final int employeeId;
  final DateTime terminationDate;
  final String terminationType;
  final bool isInsuranceStopped;
  final String? stopInsuranceMonth;
  final bool toolsReturned;
  final bool materialsTransferred;
  final bool hasUnsettledItems;
  final String? remark;
}

String terminationDateLabel(TerminationRecord record) {
  return AppDateUtils.formatDate(record.terminationDate);
}
