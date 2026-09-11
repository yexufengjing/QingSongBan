import '../../../core/database/database_enums.dart';

abstract final class PersonnelOptions {
  static const genders = ['男', '女'];
  static const employmentTypes = ['临时工', '正式工', '其他'];

  static String statusLabel(EmployeeStatus status) {
    return switch (status) {
      EmployeeStatus.active => '在岗',
      EmployeeStatus.paused => '暂停工作',
      EmployeeStatus.terminated => '已离职',
    };
  }
}

class EmployeeDraft {
  const EmployeeDraft({
    required this.employeeNo,
    required this.name,
    required this.hireDate,
    required this.status,
    this.gender,
    this.idCardNumber,
    this.birthDate,
    this.phone,
    this.address,
    this.position,
    this.team,
    this.workArea,
    this.manager,
    this.employmentType,
    this.defaultAttendanceGroupId,
    this.remark,
  });

  final String employeeNo;
  final String name;
  final String? gender;
  final String? idCardNumber;
  final DateTime? birthDate;
  final String? phone;
  final String? address;
  final DateTime hireDate;
  final EmployeeStatus status;
  final String? position;
  final String? team;
  final String? workArea;
  final String? manager;
  final String? employmentType;
  final int? defaultAttendanceGroupId;
  final String? remark;
}
