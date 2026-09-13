import 'dart:convert';

import 'package:drift/drift.dart';

import '../utils/date_utils.dart';
import 'app_database.dart';
import 'database_enums.dart';
import '../../features/payroll/domain/payroll_calculator.dart';

/// Inserts a coherent set of Chinese demo records for manual UI verification.
///
/// The seed is intentionally opt-in and idempotent. It is not called by the
/// normal application startup path unless QSB_SEED_DATA is enabled at build
/// time.
abstract final class DemoDataSeeder {
  static const markerKey = 'demo_data_seed_v1';

  static Future<bool> seed(AppDatabase database) async {
    final settings = await (database.select(
      database.appSettings,
    )..where((table) => table.settingKey.equals(markerKey))).getSingleOrNull();
    if (settings != null) return false;

    final existingEmployees = await database.listEmployees(
      includeDeleted: true,
    );
    if (existingEmployees.any(
      (employee) => employee.employeeNo.startsWith('DEMO-'),
    )) {
      return false;
    }

    final now = DateTime.now();
    final today = AppDateUtils.dateOnly(now);
    final monthStart = DateTime(today.year, today.month);
    final month = AppDateUtils.yearMonth(today);
    final previousMonth = AppDateUtils.yearMonth(
      monthStart.subtract(const Duration(days: 1)),
    );

    return database.transaction(() async {
      final productionGroupId = await database
          .into(database.attendanceGroups)
          .insert(
            AttendanceGroupsCompanion.insert(
              name: '生产一组',
              groupType: const Value('manual'),
              sortOrder: const Value(1),
              remark: const Value('演示数据：生产现场白班'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      final administrationGroupId = await database
          .into(database.attendanceGroups)
          .insert(
            AttendanceGroupsCompanion.insert(
              name: '行政支持组',
              groupType: const Value('manual'),
              sortOrder: const Value(2),
              remark: const Value('演示数据：行政与后勤岗位'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      final nightShiftGroupId = await database
          .into(database.attendanceGroups)
          .insert(
            AttendanceGroupsCompanion.insert(
              name: '夜班组',
              groupType: const Value('manual'),
              sortOrder: const Value(3),
              remark: const Value('演示数据：夜班人员'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final employeeSeeds = [
        _DemoEmployee(
          employeeNo: 'DEMO-001',
          name: '张伟',
          gender: '男',
          idCardNumber: '110101198803120019',
          birthDate: DateTime(1988, 3, 12),
          phone: '13800000001',
          address: '北京市东城区和平里街道',
          hireDate: monthStart.subtract(const Duration(days: 920)),
          position: '生产主管',
          team: '一车间',
          workArea: '特钢',
          manager: '周明远',
          employmentType: '正式工',
          groupId: productionGroupId,
          remark: '演示数据：正常在岗',
        ),
        _DemoEmployee(
          employeeNo: 'DEMO-002',
          name: '李娜',
          gender: '女',
          idCardNumber: '310101199102180026',
          birthDate: DateTime(1991, 2, 18),
          phone: '13800000002',
          address: '上海市浦东新区张江镇',
          hireDate: monthStart.subtract(const Duration(days: 660)),
          position: '人事专员',
          team: '综合办公室',
          workArea: '总部',
          manager: '陈静',
          employmentType: '正式工',
          groupId: administrationGroupId,
          remark: '演示数据：今日下午事假',
        ),
        _DemoEmployee(
          employeeNo: 'DEMO-003',
          name: '王强',
          gender: '男',
          idCardNumber: '440101198907230017',
          birthDate: DateTime(1989, 7, 23),
          phone: '13800000003',
          address: '广东省广州市番禺区',
          hireDate: monthStart.subtract(const Duration(days: 480)),
          position: '设备工程师',
          team: '设备维护班',
          workArea: '重科',
          manager: '张伟',
          employmentType: '正式工',
          groupId: productionGroupId,
          remark: '演示数据：今日存在缺勤异常，昨日加班',
        ),
        _DemoEmployee(
          employeeNo: 'DEMO-004',
          name: '刘洋',
          gender: '男',
          idCardNumber: '320102199305060014',
          birthDate: DateTime(1993, 5, 6),
          phone: '13800000004',
          address: '江苏省南京市鼓楼区',
          hireDate: monthStart.subtract(const Duration(days: 300)),
          position: '操作工',
          team: '二车间',
          workArea: '管业',
          manager: '张伟',
          employmentType: '正式工',
          groupId: productionGroupId,
          remark: '演示数据：正常在岗',
        ),
        _DemoEmployee(
          employeeNo: 'DEMO-005',
          name: '陈静',
          gender: '女',
          idCardNumber: '510101199511110024',
          birthDate: DateTime(1995, 11, 11),
          phone: '13800000005',
          address: '四川省成都市武侯区',
          hireDate: monthStart.subtract(const Duration(days: 250)),
          position: '财务专员',
          team: '财务部',
          workArea: '总部',
          manager: '周明远',
          employmentType: '正式工',
          groupId: administrationGroupId,
          remark: '演示数据：今日病假',
        ),
        _DemoEmployee(
          employeeNo: 'DEMO-006',
          name: '赵磊',
          gender: '男',
          idCardNumber: '42010619900708001X',
          birthDate: DateTime(1990, 7, 8),
          phone: '13800000006',
          address: '湖北省武汉市武昌区',
          hireDate: monthStart.subtract(const Duration(days: 190)),
          position: '仓库管理员',
          team: '仓储班',
          workArea: '物流中心',
          manager: '王强',
          employmentType: '正式工',
          groupId: nightShiftGroupId,
          remark: '演示数据：今日公休',
        ),
        _DemoEmployee(
          employeeNo: 'DEMO-007',
          name: '黄婷婷',
          gender: '女',
          idCardNumber: '330106199812030021',
          birthDate: DateTime(1998, 12, 3),
          phone: '13800000007',
          address: '浙江省杭州市西湖区',
          hireDate: monthStart.subtract(const Duration(days: 120)),
          position: '采购助理',
          team: '供应链部',
          workArea: '总部',
          manager: '李娜',
          employmentType: '临时工',
          groupId: administrationGroupId,
          remark: '演示数据：正常在岗',
        ),
        _DemoEmployee(
          employeeNo: 'DEMO-008',
          name: '周明远',
          gender: '男',
          idCardNumber: '610104198602270018',
          birthDate: DateTime(1986, 2, 27),
          phone: '13800000008',
          address: '陕西省西安市雁塔区',
          hireDate: monthStart.subtract(const Duration(days: 1500)),
          status: EmployeeStatus.paused,
          position: '运营经理',
          team: '管理组',
          workArea: '总部',
          manager: '周明远',
          employmentType: '正式工',
          groupId: administrationGroupId,
          remark: '演示数据：暂停工作',
        ),
        _DemoEmployee(
          employeeNo: 'DEMO-009',
          name: '吴敏',
          gender: '女',
          idCardNumber: '420106199207150029',
          birthDate: DateTime(1992, 7, 15),
          phone: '13800000009',
          address: '湖北省武汉市洪山区',
          hireDate: monthStart.subtract(const Duration(days: 720)),
          status: EmployeeStatus.terminated,
          position: '质检员',
          team: '质量组',
          workArea: '特钢',
          manager: '张伟',
          employmentType: '正式工',
          groupId: productionGroupId,
          remark: '演示数据：本月已离职',
        ),
        _DemoEmployee(
          employeeNo: 'DEMO-010',
          name: '孙浩',
          gender: '男',
          idCardNumber: '370102199910010013',
          birthDate: DateTime(1999, 10, 1),
          phone: '13800000010',
          address: '山东省济南市历下区',
          hireDate: monthStart.add(const Duration(days: 5)),
          position: '操作工',
          team: '一车间',
          workArea: '特钢',
          manager: '张伟',
          employmentType: '临时工',
          groupId: productionGroupId,
          remark: '演示数据：本月新入职',
        ),
      ];

      final employeeIds = <String, int>{};
      for (final seed in employeeSeeds) {
        final employeeId = await database
            .into(database.employees)
            .insert(
              EmployeesCompanion.insert(
                employeeNo: seed.employeeNo,
                name: seed.name,
                gender: Value(seed.gender),
                idCardNumber: Value(seed.idCardNumber),
                birthDate: Value(seed.birthDate),
                phone: Value(seed.phone),
                address: Value(seed.address),
                hireDate: seed.hireDate,
                status: Value(seed.status),
                position: Value(seed.position),
                team: Value(seed.team),
                workArea: Value(seed.workArea),
                manager: Value(seed.manager),
                employmentType: Value(seed.employmentType),
                defaultAttendanceGroupId: Value(seed.groupId),
                remark: Value(seed.remark),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        employeeIds[seed.employeeNo] = employeeId;
        await database
            .into(database.attendanceGroupMembers)
            .insert(
              AttendanceGroupMembersCompanion.insert(
                attendanceGroupId: seed.groupId,
                employeeId: employeeId,
                isDefault: const Value(true),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }

      final jobTypeIds = <String, int>{};
      const demoJobTypes = [
        _DemoJobType(
          name: '绿化工',
          defaultDailyWage: 128,
          sortOrder: 1,
          remark: '演示数据：园区绿化岗位',
        ),
        _DemoJobType(
          name: '环卫工',
          defaultDailyWage: 115,
          sortOrder: 2,
          remark: '演示数据：环境维护岗位',
        ),
        _DemoJobType(
          name: '保洁员',
          defaultDailyWage: 105,
          sortOrder: 3,
          remark: '演示数据：室内保洁岗位',
        ),
        _DemoJobType(
          name: '维修工',
          defaultDailyWage: 180,
          sortOrder: 4,
          remark: '演示数据：设备维护岗位',
        ),
        _DemoJobType(
          name: '司机',
          defaultDailyWage: 160,
          sortOrder: 5,
          remark: '演示数据：运输驾驶岗位',
        ),
        _DemoJobType(
          name: '其他',
          defaultDailyWage: 95,
          sortOrder: 6,
          remark: '演示数据：其他临时岗位',
        ),
        _DemoJobType(
          name: '夜班保洁',
          defaultDailyWage: 150,
          isActive: false,
          sortOrder: 7,
          remark: '演示数据：停用工种，可从菜单重新启用',
        ),
      ];
      for (final seed in demoJobTypes) {
        final jobTypeId = await database
            .into(database.wageJobTypes)
            .insert(
              WageJobTypesCompanion.insert(
                name: seed.name,
                defaultDailyWage: Value(seed.defaultDailyWage),
                isActive: Value(seed.isActive),
                sortOrder: Value(seed.sortOrder),
                remark: Value(seed.remark),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        jobTypeIds[seed.name] = jobTypeId;
        await database
            .into(database.wageRateHistory)
            .insert(
              WageRateHistoryCompanion.insert(
                jobTypeId: jobTypeId,
                dailyWage: seed.defaultDailyWage - 5,
                effectiveMonth: previousMonth,
                remark: const Value('演示数据：上月生效日薪'),
                createdAt: Value(now),
              ),
            );
        await database
            .into(database.wageRateHistory)
            .insert(
              WageRateHistoryCompanion.insert(
                jobTypeId: jobTypeId,
                dailyWage: seed.defaultDailyWage,
                effectiveMonth: month,
                remark: const Value('演示数据：本月生效日薪'),
                createdAt: Value(now),
              ),
            );
      }

      const demoWageProfiles = [
        _DemoWageProfile(
          employeeNo: 'DEMO-007',
          jobTypeName: '保洁员',
          useJobDefaultWage: true,
          remark: '演示数据：按保洁员生效日薪计算',
        ),
        _DemoWageProfile(
          employeeNo: 'DEMO-010',
          jobTypeName: '绿化工',
          useJobDefaultWage: false,
          personalDailyWage: 138,
          remark: '演示数据：个人特殊日薪',
        ),
      ];
      for (final profile in demoWageProfiles) {
        await database
            .into(database.employeeWageProfiles)
            .insert(
              EmployeeWageProfilesCompanion.insert(
                employeeId: employeeIds[profile.employeeNo]!,
                participatesInPayroll: const Value(true),
                jobTypeId: Value(jobTypeIds[profile.jobTypeName]),
                useJobDefaultWage: Value(profile.useJobDefaultWage),
                personalDailyWage: Value(profile.personalDailyWage),
                remark: Value(profile.remark),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }

      final rosterEmployeeIds = [
        for (final seed in employeeSeeds)
          if (seed.hireDate.isBefore(monthStart.add(const Duration(days: 31))))
            employeeIds[seed.employeeNo]!,
      ];
      for (final employeeId in rosterEmployeeIds) {
        final employee = await database.findEmployeeById(employeeId);
        if (employee == null) continue;
        final attendanceDays = switch (employee.employeeNo) {
          'DEMO-007' => 18.5,
          'DEMO-010' => 20.5,
          _ => 0.0,
        };
        final leaveDays = employee.employeeNo == 'DEMO-007' ? 0.5 : 0.0;
        await database
            .into(database.monthlyAttendanceRosters)
            .insert(
              MonthlyAttendanceRostersCompanion.insert(
                yearMonth: month,
                attendanceGroupId: employee.defaultAttendanceGroupId!,
                employeeId: employeeId,
                source: const Value('imported'),
                remark: const Value('演示数据：当月考勤名单'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        if (employee.status != EmployeeStatus.terminated) {
          await database
              .into(database.monthlyAttendanceSummaries)
              .insert(
                MonthlyAttendanceSummariesCompanion.insert(
                  yearMonth: month,
                  employeeId: employeeId,
                  attendanceGroupId: Value(employee.defaultAttendanceGroupId),
                  participates: const Value(true),
                  attendanceDays: Value(attendanceDays),
                  leaveDays: Value(leaveDays),
                  absentDays: Value(
                    employee.employeeNo == 'DEMO-003' ? 1.0 : 0.0,
                  ),
                  restDays: Value(
                    employee.employeeNo == 'DEMO-006' ? 1.0 : 0.0,
                  ),
                  overtimeCount: Value(
                    employee.employeeNo == 'DEMO-003' ? 1 : 0,
                  ),
                  overtimeMinutes: Value(
                    employee.employeeNo == 'DEMO-003' ? 120 : 0,
                  ),
                  monthStartStatus: const Value('正常'),
                  monthEndStatus: const Value('待确认'),
                  joinedDuringMonth: Value(employee.employeeNo == 'DEMO-010'),
                  anomalyCount: Value(
                    employee.employeeNo == 'DEMO-003' ? 2 : 0,
                  ),
                  status: const Value(MonthlySummaryStatus.pendingReview),
                  isComplete: const Value(false),
                  updatedAt: Value(now),
                ),
              );
        }
      }

      for (final summary in const [
        (employeeNo: 'DEMO-007', attendanceDays: 17.5),
        (employeeNo: 'DEMO-010', attendanceDays: 19.5),
      ]) {
        final employee = await database.findEmployeeById(
          employeeIds[summary.employeeNo]!,
        );
        if (employee == null) continue;
        await database
            .into(database.monthlyAttendanceSummaries)
            .insert(
              MonthlyAttendanceSummariesCompanion.insert(
                yearMonth: previousMonth,
                employeeId: employee.id,
                attendanceGroupId: Value(employee.defaultAttendanceGroupId),
                participates: const Value(true),
                attendanceDays: Value(summary.attendanceDays),
                monthStartStatus: const Value('正常'),
                monthEndStatus: const Value('正常'),
                isComplete: const Value(true),
                status: const Value(MonthlySummaryStatus.confirmed),
                generatedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }

      await _seedDemoPayroll(
        database: database,
        employeeIds: employeeIds,
        jobTypeIds: jobTypeIds,
        month: month,
        previousMonth: previousMonth,
        now: now,
      );

      final productionEmployeeIds = [
        employeeIds['DEMO-001']!,
        employeeIds['DEMO-003']!,
        employeeIds['DEMO-004']!,
        employeeIds['DEMO-009']!,
        employeeIds['DEMO-010']!,
      ];
      for (final employeeId in productionEmployeeIds) {
        await database
            .into(database.monthlyAttendanceRosters)
            .insert(
              MonthlyAttendanceRostersCompanion.insert(
                yearMonth: previousMonth,
                attendanceGroupId: productionGroupId,
                employeeId: employeeId,
                source: const Value('imported'),
                remark: const Value('演示数据：上月名单'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }

      final todayAttendance =
          <String, (AttendanceHalfStatus, AttendanceHalfStatus, String?)>{
            'DEMO-001': (
              AttendanceHalfStatus.present,
              AttendanceHalfStatus.present,
              '正常出勤',
            ),
            'DEMO-002': (
              AttendanceHalfStatus.present,
              AttendanceHalfStatus.leave,
              '下午事假',
            ),
            'DEMO-003': (
              AttendanceHalfStatus.absent,
              AttendanceHalfStatus.present,
              '上午未打卡',
            ),
            'DEMO-004': (
              AttendanceHalfStatus.present,
              AttendanceHalfStatus.present,
              null,
            ),
            'DEMO-005': (
              AttendanceHalfStatus.leave,
              AttendanceHalfStatus.leave,
              '病假',
            ),
            'DEMO-006': (
              AttendanceHalfStatus.rest,
              AttendanceHalfStatus.rest,
              '排班公休',
            ),
            'DEMO-007': (
              AttendanceHalfStatus.present,
              AttendanceHalfStatus.present,
              null,
            ),
            'DEMO-008': (
              AttendanceHalfStatus.stopped,
              AttendanceHalfStatus.stopped,
              '暂停工作',
            ),
          };
      for (final entry in todayAttendance.entries) {
        await database
            .into(database.attendanceRecords)
            .insert(
              AttendanceRecordsCompanion.insert(
                employeeId: employeeIds[entry.key]!,
                attendanceDate: today,
                morningStatus: Value(entry.value.$1),
                afternoonStatus: Value(entry.value.$2),
                remark: Value(entry.value.$3),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }

      final yesterday = today.subtract(const Duration(days: 1));
      await database
          .into(database.attendanceRecords)
          .insert(
            AttendanceRecordsCompanion.insert(
              employeeId: employeeIds['DEMO-003']!,
              attendanceDate: yesterday,
              morningStatus: const Value(AttendanceHalfStatus.present),
              afternoonStatus: const Value(AttendanceHalfStatus.present),
              remark: const Value('昨日正常出勤'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await database
          .into(database.leaveRecords)
          .insert(
            LeaveRecordsCompanion.insert(
              employeeId: employeeIds['DEMO-002']!,
              leaveType: const Value(LeaveType.personal),
              startDate: today,
              endDate: today,
              startPeriod: const Value(LeaveHalfPeriod.afternoon),
              endPeriod: const Value(LeaveHalfPeriod.afternoon),
              remark: const Value('办理个人事务'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.leaveRecords)
          .insert(
            LeaveRecordsCompanion.insert(
              employeeId: employeeIds['DEMO-005']!,
              leaveType: const Value(LeaveType.sick),
              startDate: yesterday,
              endDate: today,
              remark: const Value('感冒休息两天'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.leaveRecords)
          .insert(
            LeaveRecordsCompanion.insert(
              employeeId: employeeIds['DEMO-008']!,
              leaveType: const Value(LeaveType.other),
              startDate: today.subtract(const Duration(days: 2)),
              endDate: today.subtract(const Duration(days: 1)),
              remark: const Value('参加外部培训'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final overtimeDate = yesterday;
      await database
          .into(database.overtimeRecords)
          .insert(
            OvertimeRecordsCompanion.insert(
              employeeId: employeeIds['DEMO-003']!,
              overtimeDate: overtimeDate,
              startTime: DateTime(
                overtimeDate.year,
                overtimeDate.month,
                overtimeDate.day,
                18,
              ),
              endTime: DateTime(
                overtimeDate.year,
                overtimeDate.month,
                overtimeDate.day,
                20,
              ),
              durationMinutes: 120,
              overtimeType: const Value('weekday'),
              workContent: const Value('设备故障检修'),
              workLocation: const Value('重科车间'),
              registrant: const Value('张伟'),
              remark: const Value('演示数据：加班记录'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final terminationDate = today.subtract(const Duration(days: 3));
      final terminationId = await database
          .into(database.terminationRecords)
          .insert(
            TerminationRecordsCompanion.insert(
              employeeId: employeeIds['DEMO-009']!,
              terminationDate: terminationDate,
              terminationType: const Value('personal'),
              isInsuranceStopped: const Value(false),
              stopInsuranceMonth: Value(month),
              toolsReturned: const Value(false),
              materialsTransferred: const Value(true),
              hasUnsettledItems: const Value(true),
              remark: const Value('个人原因离职，待办理停保'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.reminders)
          .insert(
            RemindersCompanion.insert(
              title: '办理吴敏停保',
              reminderType: 'terminationInsurance',
              dueDate: Value(DateTime(today.year, today.month, 15, 9)),
              sourceEntityType: const Value('termination'),
              sourceEntityId: Value(terminationId),
              remark: const Value('演示数据：离职停保待确认'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      for (final employeeId in employeeIds.values) {
        final isTerminated = employeeId == employeeIds['DEMO-009'];
        await database
            .into(database.insuranceProfiles)
            .insert(
              InsuranceProfilesCompanion.insert(
                employeeId: employeeId,
                isInsured: Value(!isTerminated),
                insuranceType: const Value('employee'),
                contributionBase: const Value(6500.0),
                effectiveMonth: Value(previousMonth),
                remark: Value(isTerminated ? '待停保' : '演示数据：正常参保'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
      await database
          .into(database.insuranceChangeRecords)
          .insert(
            InsuranceChangeRecordsCompanion.insert(
              employeeId: employeeIds['DEMO-009']!,
              changeType: 'stop',
              processingStatus: const Value('pending'),
              insuranceType: const Value('employee'),
              contributionBase: const Value(6500.0),
              effectiveMonth: month,
              remark: const Value('离职后办理停保'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.reminders)
          .insert(
            RemindersCompanion.insert(
              title: '完成本月考勤汇总',
              reminderType: 'monthlySummary',
              dueDate: Value(DateTime(today.year, today.month, 25, 9)),
              leadDays: const Value(3),
              remark: const Value('演示数据：检查异常记录后生成月度汇总'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.reminders)
          .insert(
            RemindersCompanion.insert(
              title: '核对王强上午缺勤',
              reminderType: 'dailyAttendance',
              dueDate: Value(today),
              remark: const Value('演示数据：今日考勤异常'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              settingKey: markerKey,
              settingValue: const Value('已加载中国场景演示数据'),
              updatedAt: Value(now),
            ),
          );
      return true;
    });
  }

  static Future<void> _seedDemoPayroll({
    required AppDatabase database,
    required Map<String, int> employeeIds,
    required Map<String, int> jobTypeIds,
    required String month,
    required String previousMonth,
    required DateTime now,
  }) async {
    const previousRows = [
      _DemoPayrollRow(
        employeeNo: 'DEMO-007',
        employeeName: '黄婷婷',
        jobTypeName: '保洁员',
        attendanceHalfDays: 35,
        dailyWage: 100,
        dailyWageSource: 'job_history',
        remark: '演示数据：上月按工种日薪计算',
      ),
      _DemoPayrollRow(
        employeeNo: 'DEMO-010',
        employeeName: '孙浩',
        jobTypeName: '绿化工',
        attendanceHalfDays: 39,
        dailyWage: 138,
        dailyWageSource: 'personal',
        remark: '演示数据：上月个人特殊日薪',
      ),
    ];
    const currentRows = [
      _DemoPayrollRow(
        employeeNo: 'DEMO-007',
        employeeName: '黄婷婷',
        jobTypeName: '保洁员',
        attendanceHalfDays: 37,
        dailyWage: 105,
        dailyWageSource: 'job_history',
        subsidy: 200,
        insuranceDeduction: 150,
        remark: '演示数据：含交通补助和保险扣除',
      ),
      _DemoPayrollRow(
        employeeNo: 'DEMO-010',
        employeeName: '孙浩',
        jobTypeName: '绿化工',
        attendanceHalfDays: 41,
        dailyWage: 138,
        dailyWageSource: 'personal',
        subsidy: 300,
        remark: '演示数据：个人特殊日薪并含全勤补助',
      ),
    ];
    await _insertDemoPayrollBatch(
      database: database,
      employeeIds: employeeIds,
      jobTypeIds: jobTypeIds,
      month: previousMonth,
      rows: previousRows,
      status: PayrollStatus.confirmed,
      confirmedAt: now.subtract(const Duration(days: 8)),
      remark: '演示数据：上月已确认工资',
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now.subtract(const Duration(days: 8)),
    );
    await _insertDemoPayrollBatch(
      database: database,
      employeeIds: employeeIds,
      jobTypeIds: jobTypeIds,
      month: month,
      rows: currentRows,
      status: PayrollStatus.draft,
      remark: '演示数据：本月待检查工资',
      createdAt: now,
      updatedAt: now,
    );
  }

  static Future<void> _insertDemoPayrollBatch({
    required AppDatabase database,
    required Map<String, int> employeeIds,
    required Map<String, int> jobTypeIds,
    required String month,
    required List<_DemoPayrollRow> rows,
    required PayrollStatus status,
    required String remark,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? confirmedAt,
  }) async {
    final attendanceSnapshotVersion = await _attendanceSnapshotVersion(
      database,
      month,
    );
    final calculations = [
      for (final row in rows)
        PayrollCalculator.calculate(
          attendanceHalfDays: row.attendanceHalfDays,
          dailyWage: row.dailyWage,
          subsidy: row.subsidy,
          insuranceDeduction: row.insuranceDeduction,
        ),
    ];
    final batchId = await database
        .into(database.payrollBatches)
        .insert(
          PayrollBatchesCompanion.insert(
            payrollMonth: month,
            name: '${month.substring(0, 4)}年${month.substring(5)}月临时工工资',
            status: Value(status),
            employeeCount: Value(rows.length),
            attendanceHalfDaysTotal: Value(
              rows.fold(0, (sum, row) => sum + row.attendanceHalfDays),
            ),
            baseWageTotal: Value(
              PayrollCalculator.roundMoney(
                calculations.fold(0.0, (sum, item) => sum + item.baseWage),
              ),
            ),
            subsidyTotal: Value(
              PayrollCalculator.roundMoney(
                rows.fold(0.0, (sum, row) => sum + row.subsidy),
              ),
            ),
            insuranceDeductionTotal: Value(
              PayrollCalculator.roundMoney(
                rows.fold(0.0, (sum, row) => sum + row.insuranceDeduction),
              ),
            ),
            finalWageTotal: Value(
              PayrollCalculator.roundMoney(
                calculations.fold(0.0, (sum, item) => sum + item.finalWage),
              ),
            ),
            attendanceSnapshotVersion: Value(attendanceSnapshotVersion),
            confirmedAt: Value(confirmedAt),
            remark: Value(remark),
            createdAt: Value(createdAt),
            updatedAt: Value(updatedAt),
          ),
        );
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final calculation = calculations[index];
      await database
          .into(database.payrollItems)
          .insert(
            PayrollItemsCompanion.insert(
              payrollBatchId: batchId,
              employeeId: employeeIds[row.employeeNo]!,
              displayOrder: index,
              employeeNameSnapshot: row.employeeName,
              employeeNoSnapshot: row.employeeNo,
              jobTypeId: Value(jobTypeIds[row.jobTypeName]),
              jobTypeNameSnapshot: Value(row.jobTypeName),
              attendanceHalfDaysSnapshot: row.attendanceHalfDays,
              dailyWage: Value(row.dailyWage),
              dailyWageSource: Value(row.dailyWageSource),
              baseWage: Value(calculation.baseWage),
              subsidy: Value(row.subsidy),
              insuranceDeduction: Value(row.insuranceDeduction),
              finalWage: Value(calculation.finalWage),
              remark: Value(row.remark),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
            ),
          );
    }
  }

  static Future<String?> _attendanceSnapshotVersion(
    AppDatabase database,
    String month,
  ) async {
    final summaries =
        await (database.select(database.monthlyAttendanceSummaries)..where(
              (table) =>
                  table.yearMonth.equals(month) & table.isDeleted.equals(false),
            ))
            .get();
    if (summaries.isEmpty) return null;
    final snapshots = [
      for (final row in summaries)
        jsonEncode([
          row.employeeId,
          row.attendanceGroupId,
          row.participates,
          row.attendanceDays,
          row.leaveDays,
          row.absentDays,
          row.restDays,
          row.stoppedDays,
          row.overtimeCount,
          row.overtimeMinutes,
          row.monthStartStatus,
          row.monthEndStatus,
          row.joinedDuringMonth,
          row.terminatedDuringMonth,
          row.isComplete,
          row.anomalyCount,
        ]),
    ]..sort();
    return jsonEncode(snapshots);
  }
}

class _DemoJobType {
  const _DemoJobType({
    required this.name,
    required this.defaultDailyWage,
    required this.sortOrder,
    required this.remark,
    this.isActive = true,
  });

  final String name;
  final double defaultDailyWage;
  final int sortOrder;
  final String remark;
  final bool isActive;
}

class _DemoWageProfile {
  const _DemoWageProfile({
    required this.employeeNo,
    required this.jobTypeName,
    required this.useJobDefaultWage,
    required this.remark,
    this.personalDailyWage,
  });

  final String employeeNo;
  final String jobTypeName;
  final bool useJobDefaultWage;
  final double? personalDailyWage;
  final String remark;
}

class _DemoPayrollRow {
  const _DemoPayrollRow({
    required this.employeeNo,
    required this.employeeName,
    required this.jobTypeName,
    required this.attendanceHalfDays,
    required this.dailyWage,
    required this.dailyWageSource,
    required this.remark,
    this.subsidy = 0,
    this.insuranceDeduction = 0,
  });

  final String employeeNo;
  final String employeeName;
  final String jobTypeName;
  final int attendanceHalfDays;
  final double dailyWage;
  final String dailyWageSource;
  final double subsidy;
  final double insuranceDeduction;
  final String remark;
}

class _DemoEmployee {
  const _DemoEmployee({
    required this.employeeNo,
    required this.name,
    required this.gender,
    required this.idCardNumber,
    required this.birthDate,
    required this.phone,
    required this.address,
    required this.hireDate,
    required this.position,
    required this.team,
    required this.workArea,
    required this.manager,
    required this.employmentType,
    required this.groupId,
    required this.remark,
    this.status = EmployeeStatus.active,
  });

  final String employeeNo;
  final String name;
  final String gender;
  final String idCardNumber;
  final DateTime birthDate;
  final String phone;
  final String address;
  final DateTime hireDate;
  final EmployeeStatus status;
  final String position;
  final String team;
  final String workArea;
  final String manager;
  final String employmentType;
  final int groupId;
  final String remark;
}
