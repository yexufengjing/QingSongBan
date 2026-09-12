import '../../../core/database/app_database.dart';

abstract final class InsuranceOptions {
  static const types = <String>['employee', 'resident', 'commercial', 'other'];
  static const changeTypes = <String>[
    'enroll',
    'stop',
    'restore',
    'typeAdjustment',
    'informationCorrection',
  ];
  static const processingStatuses = <String>[
    'pending',
    'processing',
    'completed',
  ];

  static String typeLabel(String type) {
    return switch (type) {
      'employee' => '职工社保',
      'resident' => '居民社保',
      'commercial' => '商业保险',
      _ => '其他',
    };
  }

  static String changeTypeLabel(String type) {
    return switch (type) {
      'enroll' => '新增参保',
      'stop' => '停保',
      'restore' => '恢复参保',
      'typeAdjustment' => '保险类型调整',
      _ => '个人信息更正',
    };
  }

  static String statusLabel(String status) {
    return switch (status) {
      'processing' => '办理中',
      'completed' => '已完成',
      _ => '待办理',
    };
  }
}

class InsuranceProfileView {
  const InsuranceProfileView({required this.profile, required this.employee});

  final InsuranceProfile profile;
  final Employee employee;
}

class InsuranceChangeView {
  const InsuranceChangeView({required this.change, required this.employee});

  final InsuranceChangeRecord change;
  final Employee employee;
}

class InsuranceHistoryView {
  const InsuranceHistoryView({required this.history, required this.employee});

  final SocialSecurityBaseHistoryData history;
  final Employee employee;
}

class InsuranceProfileDraft {
  const InsuranceProfileDraft({
    required this.employeeId,
    required this.isInsured,
    this.insuranceType,
    this.contributionBase,
    this.effectiveMonth,
    this.remark,
  });

  final int employeeId;
  final bool isInsured;
  final String? insuranceType;
  final double? contributionBase;
  final String? effectiveMonth;
  final String? remark;
}

class InsuranceChangeDraft {
  const InsuranceChangeDraft({
    required this.employeeId,
    required this.changeType,
    required this.processingStatus,
    required this.effectiveMonth,
    this.insuranceType,
    this.contributionBase,
    this.remark,
  });

  final int employeeId;
  final String changeType;
  final String processingStatus;
  final String effectiveMonth;
  final String? insuranceType;
  final double? contributionBase;
  final String? remark;
}
