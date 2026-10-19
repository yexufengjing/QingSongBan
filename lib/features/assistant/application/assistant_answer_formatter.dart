import '../domain/assistant_models.dart';

class AssistantAnswerFormatter {
  const AssistantAnswerFormatter();

  AssistantAnswer formatAnswer(
    AttendanceReadResult result, {
    AssistantFieldSource yearMonthSource = AssistantFieldSource.turn,
    String? explanation,
  }) {
    final displayMonth = result.yearMonth
        .replaceFirst('-', ' 年 ')
        .replaceAll(RegExp(r'$'), ' 月');
    final text = switch (result.status) {
      AttendanceReadStatus.success => _successText(result, displayMonth),
      AttendanceReadStatus.notInRoster =>
        '${result.employeeLabel}不在 $displayMonth 的有效考勤名单中，无法按月考勤表统计。',
      AttendanceReadStatus.selectionRequired =>
        '该人员在 $displayMonth 有多个考勤来源，当前结果无法确认一致，请先选择来源。',
      AttendanceReadStatus.dataConflict => '$displayMonth 的考勤来源存在差异，暂时无法可靠汇总。',
      AttendanceReadStatus.employeeUnavailable => '该人员已不存在或已失效，请重新选择后查询。',
      AttendanceReadStatus.failure => '本地考勤读取失败，请重试。',
    };

    return AssistantAnswer(
      text: text,
      employeeLabel: result.employeeLabel,
      yearMonth: result.yearMonth,
      queriedAt: result.queriedAt,
      completeness: result.completeness,
      yearMonthSource: yearMonthSource,
      attendanceDays: result.attendanceDays,
      leaveAndRestDays: result.leaveAndRestDays,
      overtimeMinutes: result.overtimeMinutes,
      groupLabels: result.groupLabels,
      groupIds: result.groupIds,
      localDetails: result.details,
      sourceRule: result.sourceRule,
      sourcePage: result.sourcePage,
      explanation: explanation,
      error: result.error,
    );
  }

  AssistantAnswer formatVehicleSummary(VehicleAnnualRepairResult result) {
    final error =
        result.status == VehicleAnnualRepairReadStatus.success ||
            result.status == VehicleAnnualRepairReadStatus.empty
        ? null
        : result.error ?? AssistantErrorCode.unknown;
    final text = switch (result.status) {
      VehicleAnnualRepairReadStatus.success =>
        '${result.vehicle.label} ${result.year} 年共有 ${result.completedRepairCount} '
            '笔已完成维修单，实际维修费用 ${_formatMoney(result.actualAmountCents)} 元。\n'
            '按报修年份统计已完成维修单实际金额。',
      VehicleAnnualRepairReadStatus.empty =>
        '${result.vehicle.label} ${result.year} 年该口径下暂无已完成维修单。',
      VehicleAnnualRepairReadStatus.unavailable => '该车辆已失效，请重新选择。',
      VehicleAnnualRepairReadStatus.failure => '本地车辆维修汇总读取失败，请重试。',
    };
    return AssistantAnswer(
      text: text,
      employeeLabel: result.vehicle.label,
      yearMonth: result.year.toString(),
      queriedAt: result.queriedAt,
      completeness: AttendanceCompleteness.notEvaluated,
      yearMonthSource: AssistantFieldSource.input,
      sourceRule: result.sourceRule,
      sourcePage:
          '/vehicles/${result.vehicle.vehicleId}?tab=repair&year=${result.year}',
      error: error,
      vehicleSummary: result,
    );
  }

  AssistantAnswer formatVehicleRanking(VehicleRankingPage page) {
    final text = page.error != null
        ? '车辆维修费用排名读取失败，请重试。'
        : !page.hasRepairRecords
        ? '${page.year} 年没有可比较的车辆维修记录。'
        : '${page.year} 年车辆维修费用排名，已显示 ${page.returnedCount} / '
              '${page.totalVehicleCount} 辆。';
    return AssistantAnswer(
      text: text,
      employeeLabel: '全部车辆',
      yearMonth: page.year.toString(),
      queriedAt: page.queriedAt,
      completeness: AttendanceCompleteness.notEvaluated,
      yearMonthSource: AssistantFieldSource.input,
      sourceRule: page.sourceRule,
      error: page.error,
      vehicleRanking: page,
    );
  }

  String _successText(AttendanceReadResult result, String month) {
    final attendance = _formatDays(result.attendanceDays ?? 0);
    final leave = _formatDays(result.leaveAndRestDays ?? 0);
    final overtime = result.overtimeMinutes ?? 0;
    final hours = overtime ~/ 60;
    final minutes = overtime % 60;
    final completeness =
        result.completeness == AttendanceCompleteness.notEvaluated
        ? '当前已登记汇总'
        : '考勤汇总';
    return '${result.employeeLabel}在 $month，出勤 $attendance 天，请假与休息合计 $leave 天，加班 $hours 小时 $minutes 分钟。\n$completeness。';
  }

  String _formatDays(double days) =>
      days == days.roundToDouble() ? days.toInt().toString() : days.toString();

  String _formatMoney(int cents) =>
      '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}
