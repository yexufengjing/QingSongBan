import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../domain/assistant_models.dart';
import 'assistant_attendance_reader.dart';
import 'assistant_vehicle_expense_reader.dart';
import '../../payroll/data/payroll_validation_service.dart';

/// Read-only local business tools used after the model selects a domain.
/// Numeric facts and source routes are assembled from the current database.
class AssistantBusinessReader
    implements AssistantBusinessReadPort, AttendanceReadPort, VehicleReadPort, VehicleExpenseReadPort {
  AssistantBusinessReader(this._db)
    : _attendance = AssistantAttendanceReader(_db),
      _vehicleExpenses = AssistantVehicleExpenseReader(_db);

  final AppDatabase _db;
  final AssistantAttendanceReader _attendance;
  final AssistantVehicleExpenseReader _vehicleExpenses;

  @override
  Future<AssistantBusinessReadResult> read(AssistantBusinessQuery query) async {
    final now = query.now ?? DateTime.now();
    final month = query.yearMonth ?? _month(now);
    final subject = query.subject?.trim().isNotEmpty == true
        ? query.subject!.trim()
        : null;
    return switch (query.domain) {
      AssistantBusinessType.personnel => _personnel(query, now, subject),
      AssistantBusinessType.payroll => _payroll(query, now, month, subject),
      AssistantBusinessType.inventory => _inventory(query, now, subject),
      AssistantBusinessType.purchase => _purchase(query, now, subject),
      AssistantBusinessType.distribution => _distribution(query, now, subject),
      AssistantBusinessType.vehicleMaintenance => _vehicleMaintenance(query, now, subject),
      AssistantBusinessType.vehicleReminders => _vehicleReminders(query, now, subject),
      AssistantBusinessType.gardenRepair => _gardenRepair(query, now, subject),
      _ => _empty(query.domain, now, '当前业务域由专用查询处理。', '/'),
    };
  }

  Future<AssistantBusinessReadResult> _personnel(
    AssistantBusinessQuery query,
    DateTime now,
    String? subject,
  ) async {
    final rows = (await _db.select(_db.employees).get())
        .where((row) => !row.isDeleted &&
            (query.employeeId == null || row.id == query.employeeId) &&
            _matches(subject, '${row.name} ${row.employeeNo} ${row.position ?? ''}'))
        .toList();
    final shown = rows.take(6).toList();
    return _result(query.domain, '人员档案', now, 'employee_profile_local_v1', shown.length == 1 ? '/personnel/${shown.single.id}' : '/personnel',
        shown.isEmpty ? '没有找到匹配的有效人员档案。' : '找到 ${rows.length} 位匹配人员，展示姓名、工号、岗位和在职状态。', [
      for (final row in shown)
        AssistantBusinessFact(
          label: '${row.name}（${row.employeeNo}）',
          value: '${row.position ?? '未登记岗位'} · ${row.status == EmployeeStatus.active ? '在职' : row.status == EmployeeStatus.paused ? '暂停' : '离职'}',
          explanation: '入职日期 ${_date(row.hireDate)}；未读取身份证号、手机号和住址。',
          sourcePage: '/personnel/${row.id}',
        ),
    ]);
  }

  Future<AssistantBusinessReadResult> _payroll(
    AssistantBusinessQuery query,
    DateTime now,
    String month,
    String? subject,
  ) async {
    final batch = await (_db.select(_db.payrollBatches)
          ..where((r) => r.payrollMonth.equals(month) & r.isDeleted.equals(false)))
        .getSingleOrNull();
    if (batch == null) {
      return _result(query.domain, '工资查询 · $month', now, 'payroll_batch_month_v1', '/reports/payroll',
          '$month 没有工资批次。', const []);
    }
    final items = (await (_db.select(_db.payrollItems)
              ..where((r) => r.payrollBatchId.equals(batch.id)))
            .get())
        .where((r) => !r.isManuallyRemoved &&
            (query.employeeId == null || r.employeeId == query.employeeId) &&
            _matches(subject, '${r.employeeNameSnapshot} ${r.employeeNoSnapshot}'))
        .toList();
    final total = items.fold<double>(0, (sum, row) => sum + row.finalWage);
    final allItems = (await (_db.select(_db.payrollItems)
          ..where((r) => r.payrollBatchId.equals(batch.id)))
        .get());
    final summaries = (await (_db.select(_db.monthlyAttendanceSummaries)
          ..where((r) => r.yearMonth.equals(month) & r.isDeleted.equals(false)))
        .get());
    final currentVersion = _attendanceSnapshotVersion(summaries);
    final validation = await PayrollValidationService(_db).validate(
      batch: batch,
      items: allItems,
      currentAttendanceSnapshotVersion: currentVersion,
      attendanceSummaryConfirmed: summaries.isNotEmpty && summaries.every(
        (row) => row.status == MonthlySummaryStatus.confirmed,
      ),
    );
    final selectedEmployeeIds = items.map((item) => item.employeeId).toSet();
    final groupedIssues = <int?, List<String>>{};
    for (final issue in [...validation.errors, ...validation.warnings]) {
      if (issue.employeeId != null && !selectedEmployeeIds.contains(issue.employeeId)) continue;
      final employeeId = issue.employeeId ??
          (selectedEmployeeIds.length == 1 ? selectedEmployeeIds.single : null);
      groupedIssues.putIfAbsent(employeeId, () => []).add(issue.message);
    }
    final facts = <AssistantBusinessFact>[
      if (subject == null && query.employeeId == null)
        AssistantBusinessFact(label: '工资批次', value: '$month · ${batch.status} · ${items.length} 人'),
      if (subject == null && query.employeeId == null)
        AssistantBusinessFact(label: '实发合计', value: '${_money(total)} 元', explanation: '按每人实发金额累加。'),
      for (final item in items.take(6))
        AssistantBusinessFact(label: '${item.employeeNameSnapshot}（${item.employeeNoSnapshot}）', value: '实发 ${_money(item.finalWage)} 元', explanation: '出勤快照 ${item.attendanceHalfDaysSnapshot / 2} 天；基本工资 ${_money(item.baseWage)} 元 + 补贴 ${_money(item.subsidy)} 元 − 扣款 ${_money(item.insuranceDeduction)} 元。', sourcePage: '/reports/payroll/item/${item.id}'),
      for (final entry in groupedIssues.entries)
          AssistantBusinessFact(
            label: '工资待核对',
            value: entry.value.join('；'),
            explanation: '按照工资校验规则核对；查询不会修改工资批次或提醒。',
            sourcePage: allItems
                    .where((item) => item.employeeId == entry.key)
                    .map((item) => '/reports/payroll/item/${item.id}')
                    .firstOrNull ??
                '/reports/payroll',
          ),
    ];
    final result = _result(query.domain, '工资查询 · $month', now, 'payroll_items_sum_and_attendance_snapshot_v1', items.length == 1 ? '/reports/payroll/item/${items.single.id}' : '/reports/payroll',
        '$month 实发合计 ${_money(total)} 元，${items.length} 人；按工资明细的出勤快照、基本工资、补贴和扣款解释构成。', facts);
    if (items.length != 1) return result;
    final employee = await (_db.select(_db.employees)..where((r) => r.id.equals(items.single.employeeId))).getSingleOrNull();
    if (employee == null) return result;
    final attendance = await _attendance.readMonth(ResolvedAttendanceQuery(
      employee: ResolvedEmployee(employeeId: employee.id, label: employee.name, employeeNumber: employee.employeeNo),
      yearMonth: month,
      yearMonthSource: AssistantFieldSource.turn,
    ));
    final related = AssistantBusinessReadResult(
      domain: AssistantBusinessType.attendance,
      title: '考勤依据 · ${employee.name} · $month',
      summary: attendance.status == AttendanceReadStatus.success
          ? '出勤 ${attendance.attendanceDays ?? 0} 天，请假与休息 ${attendance.leaveAndRestDays ?? 0} 天，加班 ${attendance.overtimeMinutes ?? 0} 分钟。'
          : '该人员本月考勤依据当前不可用（${attendance.status.name}）。',
      queriedAt: attendance.queriedAt,
      sourceRule: attendance.sourceRule,
      sourcePage: '/attendance/monthly-table?month=$month${attendance.groupIds.isEmpty ? '' : '&groupId=${attendance.groupIds.first}'}',
      facts: [if (attendance.attendanceDays != null) AssistantBusinessFact(label: '出勤天数', value: '${attendance.attendanceDays} 天')],
      error: attendance.error,
    );
    return AssistantBusinessReadResult(domain: result.domain, title: result.title, summary: result.summary, queriedAt: result.queriedAt, sourceRule: result.sourceRule, sourcePage: result.sourcePage, facts: result.facts, relatedReads: [related]);
  }

  Future<AssistantBusinessReadResult> _inventory(AssistantBusinessQuery query, DateTime now, String? subject) async {
    final rows = (await _db.select(_db.inventoryMaterials).get())
        .where((r) => !r.isDeleted && r.status == 'active' && _matches(subject, '${r.materialName} ${r.materialCode} ${r.modelSpec ?? ''}'))
        .toList();
    final low = rows.where((r) => r.warningEnabled && r.currentStock <= r.minStock).toList()
      ..sort((a, b) => (a.currentStock - a.minStock).compareTo(b.currentStock - b.minStock));
    final displayRows = subject != null && query.operation != 'lowStock' ? rows : low;
    final facts = <AssistantBusinessFact>[
      AssistantBusinessFact(label: '物资种类', value: '${rows.length} 种'),
      AssistantBusinessFact(label: '低库存', value: '${low.length} 种', explanation: '当前库存小于或等于预警下限。'),
      for (final row in displayRows.take(6))
        AssistantBusinessFact(
          label: '${row.materialName}（${row.materialCode}）',
          value: '现存 ${_qty(row.currentStock)} ${row.unitName} / 下限 ${_qty(row.minStock)}',
          explanation: '${row.currentStock < row.minStock ? '比预警下限少 ${_qty(row.minStock - row.currentStock)} ${row.unitName}' : row.currentStock == row.minStock ? '已达到预警下限' : '高于预警下限 ${_qty(row.currentStock - row.minStock)} ${row.unitName}'}；参考价 ${row.referencePriceCent == null ? '未登记' : '${_money(row.referencePriceCent! / 100)} 元'}',
          sourcePage: '/inventory/materials/${row.id}',
        ),
    ];
    final result = _result(query.domain, '库存与补货', now, 'inventory_current_stock_vs_min_v1', displayRows.length == 1 ? '/inventory/materials/${displayRows.single.id}' : '/inventory/materials',
      rows.isEmpty ? '没有找到匹配的有效库存物资。' : '当前查询 ${rows.length} 种物资，其中 ${low.length} 种低于或达到预警下限。', facts);
    if (low.isEmpty) return result;
    final materialIds = low.map((r) => r.id).toSet();
    final requests = (await _db.select(_db.purchaseRequests).get()).where((r) => !r.isDeleted).toList();
    final items = (await _db.select(_db.purchaseRequestItems).get()).where((r) => r.inventoryMaterialId != null && materialIds.contains(r.inventoryMaterialId)).toList();
    final requestIds = items.map((r) => r.requestId).toSet();
    final matching = requests.where((r) => requestIds.contains(r.id)).toList();
    final linked = _result(AssistantBusinessType.purchase, '关联采购', now, 'purchase_item_material_name_link_v1', '/purchase',
      matching.isEmpty ? '低库存物资没有匹配到采购明细。' : '找到 ${matching.length} 个相关采购单：${matching.map((r) => '${r.title}（${_purchaseStatus(r.status)}）').join('；')}。', [
        for (final row in matching.take(5)) AssistantBusinessFact(label: row.title, value: _purchaseStatus(row.status), sourcePage: '/purchase/detail/${row.id}'),
      ]);
    return AssistantBusinessReadResult(domain: result.domain, title: result.title, summary: result.summary, queriedAt: result.queriedAt, sourceRule: result.sourceRule, sourcePage: result.sourcePage, facts: result.facts, relatedReads: [linked]);
  }

  Future<AssistantBusinessReadResult> _purchase(AssistantBusinessQuery query, DateTime now, String? subject) async {
    final allRequests = (await _db.select(_db.purchaseRequests).get())
        .where((r) => !r.isDeleted).toList();
    final items = await _db.select(_db.purchaseRequestItems).get();
    final materials = await _db.select(_db.inventoryMaterials).get();
    final materialMatches = materials.where((material) =>
      !material.isDeleted && _matches(subject, '${material.materialName} ${material.materialCode} ${material.modelSpec ?? ''}')).map((r) => r.id).toSet();
    final requests = allRequests.where((request) {
      final lines = items.where((item) => item.requestId == request.id).toList();
      final titleMatches = _matches(subject, '${request.title} ${request.oaRequestNo ?? ''} ${request.status}');
      final itemMatches = subject == null || lines.any((item) =>
        (item.inventoryMaterialId != null && materialMatches.contains(item.inventoryMaterialId)) ||
        _matches(subject, '${item.itemName} ${item.specification ?? ''}'));
      final partial = lines.any((item) => item.receivedQuantity > 0 && item.receivedQuantity < item.requestQuantity);
      final pending = !const {'stocked', 'cancelled'}.contains(request.status);
      final operationMatches = switch (query.operation) {
        'pending' => pending && lines.any((item) => item.receivedQuantity < item.requestQuantity),
        'partial' => partial,
        _ => true,
      };
      return (subject == null || titleMatches || itemMatches) && operationMatches;
    }).toList()..sort((a,b) => b.updatedAt.compareTo(a.updatedAt));
    final facts = <AssistantBusinessFact>[];
    for (final row in requests.take(6)) {
      final lines = items.where((i) => i.requestId == row.id).toList();
      facts.add(AssistantBusinessFact(label: row.title, value: _purchaseStatus(row.status), explanation: lines.map((i) => '${i.itemName} ${_qty(i.receivedQuantity)}/${_qty(i.requestQuantity)} ${i.unit}').join('；'), sourcePage: '/purchase/detail/${row.id}'));
    }
    return _result(query.domain, '采购进度', now, 'purchase_status_items_received_v1', requests.length == 1 ? '/purchase/detail/${requests.single.id}' : '/purchase', requests.isEmpty ? '没有找到匹配的采购记录。' : '找到 ${requests.length} 个采购单；按每种物资分别展示申请与入库数量。采购申请没有可靠的实际总额字段。', facts);
  }

  Future<AssistantBusinessReadResult> _distribution(AssistantBusinessQuery query, DateTime now, String? subject) async {
    final month = query.yearMonth ?? _month(now);
    final rows = await _db.customSelect(
      '''SELECT e.*, b.benefit_month FROM item_distribution_entries e
         JOIN item_distribution_batches b ON b.id=e.batch_id
         WHERE b.category='welfare' AND b.is_deleted=0 AND e.is_deleted=0
           AND b.benefit_month=?
         ORDER BY e.recipient_name, e.item_name''',
      variables: [Variable.withString(month)],
    ).get();
    final selected = rows.where((row) {
      final data = row.data;
      final status = data['status'] as String;
      final matchesStatus = switch (query.operation) {
        'received' => status == 'received',
        'notReceived' => status == 'not_received',
        _ => true,
      };
      return matchesStatus && _matches(subject, '${data['recipient_name']} ${data['item_name']} ${data['item_code']}');
    }).toList();
    final received = selected.where((r) => r.data['status'] == 'received').length;
    final notReceived = selected.length - received;
    final facts = [
      AssistantBusinessFact(label: '福利月份', value: month),
      AssistantBusinessFact(label: '领取状态', value: '已领取 $received 条 · 未领取 $notReceived 条'),
      for (final row in selected.take(12))
        AssistantBusinessFact(
          label: '${row.data['recipient_name']} · ${row.data['item_name']}',
          value: '${row.data['status'] == 'received' ? '已领取' : '未领取'} · ${_qty((row.data['quantity'] as num).toDouble())} ${row.data['unit']}',
          explanation: '福利归属 ${row.data['benefit_month']}；实际发放 ${row.data['actual_distribution_month'] ?? '未登记'}。',
          sourcePage: '/items?year=${month.substring(0, 4)}&month=${month.substring(5, 7)}',
        ),
    ];
    return _result(query.domain, '福利领取 · $month', now, 'welfare_distribution_entries_status_month_v1', '/items?year=${month.substring(0, 4)}&month=${month.substring(5, 7)}', selected.isEmpty ? '$month 没有符合条件的福利领取记录。' : '$month 找到 ${selected.length} 条福利记录：已领取 $received 条，未领取 $notReceived 条。', facts);
  }

  Future<AssistantBusinessReadResult> _vehicleMaintenance(AssistantBusinessQuery query, DateTime now, String? subject) async {
    final orders = (await _db.select(_db.repairOrders).get()).where((r) => !r.isDeleted).toList();
    final vehicles = await _db.select(_db.vehicles).get();
    final selected = orders.where((r) {
      final vehicle = _firstOrNull(vehicles.where((v) => v.id == r.vehicleId));
      return (query.vehicleId == null || r.vehicleId == query.vehicleId) && _matches(subject, '${r.repairNo} ${r.symptom} ${r.project ?? ''} ${vehicle?.name ?? ''} ${vehicle?.vehicleNo ?? ''} ${vehicle?.licensePlate ?? ''}');
    }).toList()..sort((a,b) => b.reportDate.compareTo(a.reportDate));
    final facts = [for (final row in selected.take(6))
      AssistantBusinessFact(label: '${_firstOrNull(vehicles.where((v)=>v.id==row.vehicleId))?.name ?? '车辆'} · ${row.repairNo}', value: '${_repairStatus(row.status.name)} · 报修 ${_date(row.reportDate)}${row.completedAt == null ? '' : ' · 完成 ${_date(row.completedAt!)}'}', explanation: '${row.symptom}；${row.actualAmountCents > 0 ? '实际费用 ${_money(row.actualAmountCents / 100)} 元' : '尚无实际费用'}', sourcePage: '/vehicles/repairs/${row.id}')];
    return _result(query.domain, '车辆维修进度', now, 'vehicle_repair_order_status_v1', selected.length == 1 ? '/vehicles/repairs/${selected.single.id}' : '/vehicles/repairs', selected.isEmpty ? '没有找到匹配的车辆维修单。' : '找到 ${selected.length} 条维修记录，展示最近 ${facts.length} 条。', facts);
  }

  Future<AssistantBusinessReadResult> _vehicleReminders(AssistantBusinessQuery query, DateTime now, String? subject) async {
    final vehicles = (await _db.select(_db.vehicles).get()).where((v) => !v.isDeleted &&
        (query.vehicleId == null || v.id == query.vehicleId) &&
        _matches(subject, '${v.name} ${v.vehicleNo} ${v.licensePlate ?? ''}')).toList();
    final vehicleById = {for (final vehicle in vehicles) vehicle.id: vehicle};
    final vehicleIds = vehicleById.keys.toSet();
    final links = (await _db.select(_db.reminderLinks).get()).where((link) => link.entityType == 'vehicle' && vehicleIds.contains(link.entityId)).toList();
    final linkedVehicleByReminder = {for (final link in links) link.reminderId: link.entityId};
    final rows = (await _db.select(_db.reminders).get()).where((r) => !r.isDeleted && r.isEnabled && !r.isCompleted && ((r.sourceEntityType == 'vehicle' && vehicleIds.contains(r.sourceEntityId)) || linkedVehicleByReminder.containsKey(r.id))) .toList()
      ..sort((a,b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
    final facts = [for (final row in rows.take(8))
      AssistantBusinessFact(label: row.title, value: row.dueDate == null ? '未设日期' : '${_date(row.dueDate!)} · ${row.dueDate!.isBefore(now) ? '已逾期' : '待处理'}', explanation: '${vehicleById[row.sourceEntityId ?? linkedVehicleByReminder[row.id]]?.name ?? '车辆'} · ${row.priority} · ${row.category}', sourcePage: '/settings/reminders/${row.id}/edit')];
    final firstReminderVehicle = rows.length == 1
        ? (linkedVehicleByReminder[rows.single.id] ?? rows.single.sourceEntityId)
        : null;
    return _result(query.domain, '车辆提醒', now, 'vehicle_linked_enabled_open_reminders_due_date_v1', firstReminderVehicle == null ? '/settings/reminders' : '/vehicles/$firstReminderVehicle?tab=reminder', rows.isEmpty ? '没有车辆待办提醒。' : '找到 ${rows.length} 条车辆关联、启用且未完成的提醒。', facts);
  }

  Future<AssistantBusinessReadResult> _gardenRepair(AssistantBusinessQuery query, DateTime now, String? subject) async {
    final groups = (await _db.select(_db.gardenToolRepairGroups).get()).where((r) => r.deletedAt == null).toList();
    final items = (await _db.select(_db.gardenToolRepairItems).get()).where((r) => r.deletedAt == null).toList();
    final groupById = {for (final row in groups) row.id: row};
    final month = query.yearMonth ?? _month(now);
    final previousMonth = _previousMonth(month);
    final specMatch = RegExp(r'(\d+\s*(?:厘米|cm|mm|毫米))', caseSensitive: false).firstMatch(query.question)?.group(1)?.replaceAll(' ', '');
    final unitMatch = _gardenUnitFromQuestion(query.question);
    final selected = items.where((item) {
      final group = groupById[item.groupId];
      return group != null &&
          _matches(subject, '${item.projectName} ${item.specModel ?? ''} ${item.remark ?? ''}') &&
          (specMatch == null || (item.specModel ?? '').replaceAll(' ', '').toLowerCase().contains(specMatch.toLowerCase())) &&
          (unitMatch == null || item.countUnit == unitMatch) &&
          (query.operation == 'comparePrice'
              ? {month, previousMonth}.contains(group.repairMonth)
              : group.repairMonth == month);
    }).toList();
    final byComparableItem = <String, List<({GardenToolRepairGroup group, GardenToolRepairItem item})>>{};
    var monthlyTotalCents = 0;
    for (final item in selected) {
      final group = groupById[item.groupId]!;
      monthlyTotalCents += item.amountCents;
      final key = '${item.projectName}\u0000${item.specModel ?? ''}\u0000${item.countUnit}';
      byComparableItem.putIfAbsent(key, () => []).add((group: group, item: item));
    }
    if (query.operation == 'monthlyTotal') {
      return _result(query.domain, '园林维修月费用 · $month', now, 'garden_repair_amount_sum_by_month_v1', '/garden-tool-repairs/analysis?year=${month.substring(0, 4)}&month=${month.substring(5, 7)}',
          '$month 园林维修登记金额合计 ${_money(monthlyTotalCents / 100)} 元。', [
      AssistantBusinessFact(label: '维修金额合计', value: '${_money(monthlyTotalCents / 100)} 元', explanation: '按维修登记金额逐项累加。'),
        AssistantBusinessFact(label: '维修明细', value: '${selected.length} 条'),
      ]);
    }
    final byProject = <String, List<({GardenToolRepairGroup group, GardenToolRepairItem item})>>{};
    for (final entry in byComparableItem.entries) {
      final rows = entry.value;
      final months = rows.map((row) => row.group.repairMonth).toSet();
      if (query.operation != 'comparePrice' || months.length > 1) {
        byProject['${rows.first.item.projectName} · ${rows.first.item.specModel ?? '未填规格'} · ${rows.first.item.countUnit}'] = rows;
      }
    }
    final facts = <AssistantBusinessFact>[];
    for (final entry in byProject.entries.take(8)) {
      final rows = entry.value;
      final sorted = rows.toList()..sort((a, b) => a.group.repairMonth.compareTo(b.group.repairMonth));
      final first = sorted.first.item.unitPriceCents;
      final latest = sorted.last.item.unitPriceCents;
      facts.add(AssistantBusinessFact(label: entry.key, value: '${sorted.length} 次记录 · ${_money(first / 100)} → ${_money(latest / 100)} 元/${sorted.last.item.countUnit}', explanation: sorted.map((row) => '${row.group.repairMonth} 数量${_qty(row.item.quantity)}，单价${_money(row.item.unitPriceCents / 100)}元，金额${_money(row.item.amountCents / 100)}元').join('；'), sourcePage: '/garden-tool-repairs/analysis?year=${sorted.last.group.repairMonth.substring(0, 4)}&month=${sorted.last.group.repairMonth.substring(5, 7)}'));
    }
    return _result(query.domain, '园林工具维修与价格', now, 'garden_repair_price_by_project_spec_unit_v1', '/garden-tool-repairs/analysis?year=${month.substring(0, 4)}&month=${month.substring(5, 7)}', selected.isEmpty ? '$month 没有找到匹配的园林维修项目。' : query.operation == 'comparePrice' ? '在$previousMonth与$month间，按项目、规格和计价单位比较登记单价。' : '展示$month匹配项目的登记单价。', facts);
  }

  AssistantBusinessReadResult _result(AssistantBusinessType domain, String title, DateTime now, String rule, String page, String summary, List<AssistantBusinessFact> facts) => AssistantBusinessReadResult(domain: domain, title: title, summary: summary, queriedAt: now, sourceRule: rule, sourcePage: page, facts: facts);
  AssistantBusinessReadResult _empty(AssistantBusinessType domain, DateTime now, String summary, String page) => _result(domain, '业务查询', now, 'unsupported_business_domain_v1', page, summary, const []);

  bool _matches(String? subject, String haystack) => subject == null || subject.isEmpty || haystack.contains(subject);
  String _month(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  String _previousMonth(String month) {
    final year = int.parse(month.substring(0, 4));
    final number = int.parse(month.substring(5, 7));
    final previous = DateTime(year, number - 1);
    return _month(previous);
  }
  String? _gardenUnitFromQuestion(String question) {
    const units = ['平方米', '立方米', '公里', '小时', '台', '片', '套', '个', '件', '把', '支', '张', '卷', '双', '桶', '箱', '包', '根', '米'];
    for (final unit in units) {
      if (question.contains('按$unit')) return unit;
    }
    return null;
  }
  String _date(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _money(double amount) => amount.toStringAsFixed(2);
  String _qty(double quantity) => quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 2);
  String _purchaseStatus(String status) => switch (status) { 'pending_apply' => '待申报', 'applied' => '已申报', 'purchasing' => '采购中', 'pending_receive' => '待入库', 'stocked' => '已入库', 'cancelled' => '已取消', _ => status };
  String _repairStatus(String status) => switch (status) { 'reported' => '待接单', 'pendingRepair' => '待维修', 'repairing' => '维修中', 'completed' => '已完成', 'cancelled' => '已取消', _ => status };

  @override Future<EmployeeResolution> resolveEmployee(EmployeeSelector selector) => _attendance.resolveEmployee(selector);
  @override Future<EmployeeResolution> resolveCandidate(String candidateRef) => _attendance.resolveCandidate(candidateRef);
  @override Future<AttendanceReadResult> readMonth(ResolvedAttendanceQuery query) => _attendance.readMonth(query);
  @override Future<VehicleResolution> resolveVehicle(VehicleSelector selector) => _attendance.resolveVehicle(selector);
  @override Future<VehicleResolution> resolveVehicleCandidate(String candidateRef) => _attendance.resolveVehicleCandidate(candidateRef);
  @override Future<VehicleAnnualRepairResult> readVehicleAnnualRepairs(ResolvedVehicleAnnualRepairQuery query) => _attendance.readVehicleAnnualRepairs(query);
  @override Future<VehicleRankingPage> readAnnualVehicleRanking(ResolvedVehicleRankingQuery query) => _attendance.readAnnualVehicleRanking(query);
  @override Future<VehicleRankingPage> readNextVehicleRankingPage({required String resultRef, required String cursor}) => _attendance.readNextVehicleRankingPage(resultRef: resultRef, cursor: cursor);
  @override Future<VehicleExpensePeriodResult> readVehicleExpenses(VehicleExpenseToolRequest request) => _vehicleExpenses.readVehicleExpenses(request);
  @override Future<VehicleExpensePeerResult> comparePeerVehicleExpenses(VehicleExpenseToolRequest request) => _vehicleExpenses.comparePeerVehicleExpenses(request);
}

T? _firstOrNull<T>(Iterable<T> values) => values.isEmpty ? null : values.first;

String? _attendanceSnapshotVersion(List<MonthlyAttendanceSummary> summaries) {
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

