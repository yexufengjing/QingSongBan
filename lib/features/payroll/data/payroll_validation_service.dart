import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../domain/payroll_calculator.dart';
import '../domain/payroll_models.dart';

class PayrollValidationService {
  const PayrollValidationService(this._database);

  final AppDatabase _database;

  Future<PayrollValidationResult> validate({
    required PayrollBatche batch,
    required List<PayrollItem> items,
    required String? currentAttendanceSnapshotVersion,
    required bool attendanceSummaryConfirmed,
  }) async {
    final errors = <PayrollValidationIssue>[];
    final warnings = <PayrollValidationIssue>[];
    if (!attendanceSummaryConfirmed) {
      errors.add(
        const PayrollValidationIssue(
          code: 'attendance_summary_unconfirmed',
          message: '月度考勤汇总尚未确认，不能确认工资',
        ),
      );
    }
    if (currentAttendanceSnapshotVersion != batch.attendanceSnapshotVersion) {
      warnings.add(
        const PayrollValidationIssue(
          code: 'attendance_changed',
          message: '考勤汇总在工资生成后发生变化，请先同步最新考勤',
        ),
      );
    }

    final active = items.where((item) => !item.isManuallyRemoved).toList();
    final seenEmployees = <int>{};
    for (final item in active) {
      final employee = await _database.findEmployeeById(item.employeeId);
      if (employee == null || employee.isDeleted) {
        errors.add(
          PayrollValidationIssue(
            code: 'missing_employee',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 的人员记录不存在或已被移除',
          ),
        );
      }
      if (!seenEmployees.add(item.employeeId)) {
        errors.add(
          PayrollValidationIssue(
            code: 'duplicate_employee',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 在工资批次中重复',
          ),
        );
      }
      if (item.jobTypeId == null ||
          (item.jobTypeNameSnapshot ?? '').trim().isEmpty) {
        errors.add(
          PayrollValidationIssue(
            code: 'missing_job_type',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 未配置工资工种',
          ),
        );
      }
      final profile =
          await (_database.select(_database.employeeWageProfiles)
                ..where((table) => table.employeeId.equals(item.employeeId))
                ..where((table) => table.isDeleted.equals(false)))
              .getSingleOrNull();
      if (profile?.jobTypeId != null &&
          item.jobTypeId != null &&
          profile!.jobTypeId != item.jobTypeId) {
        warnings.add(
          PayrollValidationIssue(
            code: 'job_type_changed',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 的工资工种与当前人员资料不一致',
          ),
        );
      }
      if (!item.dailyWage.isFinite || item.dailyWage <= 0) {
        errors.add(
          PayrollValidationIssue(
            code: 'missing_daily_wage',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 未配置有效日薪',
          ),
        );
      }
      if (item.attendanceHalfDaysSnapshot < 0) {
        errors.add(
          PayrollValidationIssue(
            code: 'invalid_attendance',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 的出勤天数无效',
          ),
        );
      }
      final calculation = PayrollCalculator.calculate(
        attendanceHalfDays: item.attendanceHalfDaysSnapshot,
        dailyWage: item.dailyWage,
        subsidy: item.subsidy,
        insuranceDeduction: item.insuranceDeduction,
      );
      if (calculation.insuranceExceedsAvailable) {
        warnings.add(
          PayrollValidationIssue(
            code: 'insurance_exceeds_available',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 的保险扣除超过基础工资与补助，最终工资将记为 0.00',
          ),
        );
      }
      if (item.attendanceHalfDaysSnapshot == 0 && item.isManuallyAdded) {
        warnings.add(
          PayrollValidationIssue(
            code: 'manual_zero_attendance',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 本月无出勤但被人工加入工资名单',
          ),
        );
      }
      if (employee?.status == EmployeeStatus.terminated &&
          item.attendanceHalfDaysSnapshot > 0) {
        warnings.add(
          PayrollValidationIssue(
            code: 'terminated_with_attendance',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 已离职但本月存在有效出勤',
          ),
        );
      }
      if (calculation.preFloorFinalWage < 0) {
        warnings.add(
          PayrollValidationIssue(
            code: 'final_wage_clamped',
            employeeId: item.employeeId,
            message: '${item.employeeNameSnapshot} 核算前工资小于 0，最终工资已归零',
          ),
        );
      }
    }
    if (batch.status == PayrollStatus.locked) {
      errors.add(
        const PayrollValidationIssue(code: 'locked', message: '工资批次已锁定'),
      );
    }
    return PayrollValidationResult(errors: errors, warnings: warnings);
  }
}
