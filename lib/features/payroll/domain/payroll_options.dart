import '../../../core/database/database_enums.dart';

abstract final class PayrollOptions {
  static const defaultJobTypes = ['绿化工', '环卫工', '保洁员', '维修工', '司机', '其他'];

  static String statusLabel(PayrollStatus status) {
    return switch (status) {
      PayrollStatus.draft => '草稿',
      PayrollStatus.pendingReview => '待检查',
      PayrollStatus.confirmed => '已确认',
      PayrollStatus.locked => '已锁定',
    };
  }

  static String dailyWageSourceLabel(String source) {
    return switch (source) {
      'batch' => '批次人工调整',
      'personal' => '个人特殊日薪',
      'job_history' => '工种生效日薪',
      'job_default' => '工种默认日薪',
      _ => '未配置',
    };
  }

  static String insuranceSourceLabel(String source) {
    return source == 'auto' ? '保险资料带入' : '人工填写';
  }
}
