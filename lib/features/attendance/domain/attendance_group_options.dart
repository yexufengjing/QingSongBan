import '../../../core/database/app_database.dart';

class AttendanceGroupDraft {
  const AttendanceGroupDraft({
    required this.name,
    this.groupType = 'manual',
    this.isEnabled = true,
    this.sortOrder = 0,
    this.remark,
  });

  final String name;
  final String groupType;
  final bool isEnabled;
  final int sortOrder;
  final String? remark;
}

class AttendanceGroupSummary {
  const AttendanceGroupSummary({
    required this.group,
    required this.memberCount,
  });

  final AttendanceGroup group;
  final int memberCount;
}

class AttendanceGroupMemberView {
  const AttendanceGroupMemberView({
    required this.membership,
    required this.employee,
  });

  final AttendanceGroupMember membership;
  final Employee employee;
}
