import 'dart:io';

import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../personnel/domain/personnel_options.dart';

class PersonnelImportIssue {
  const PersonnelImportIssue({required this.rowNumber, required this.message});

  final int rowNumber;
  final String message;

  @override
  String toString() => '第$rowNumber行：$message';
}

class PersonnelImportRow {
  const PersonnelImportRow({
    required this.employeeNo,
    required this.name,
    required this.hireDate,
    this.gender,
    this.idCardNumber,
    this.birthDate,
    this.phone,
    this.position,
    this.team,
    this.workArea,
    this.manager,
    this.employmentType,
    this.attendanceGroupId,
    this.remark,
    this.isInsured = false,
  });

  final String employeeNo;
  final String name;
  final DateTime hireDate;
  final String? gender;
  final String? idCardNumber;
  final DateTime? birthDate;
  final String? phone;
  final String? position;
  final String? team;
  final String? workArea;
  final String? manager;
  final String? employmentType;
  final int? attendanceGroupId;
  final String? remark;
  final bool isInsured;
}

class PersonnelImportPreview {
  const PersonnelImportPreview({required this.rows, required this.issues});

  final List<PersonnelImportRow> rows;
  final List<PersonnelImportIssue> issues;

  bool get canImport => rows.isNotEmpty && issues.isEmpty;
}

class ExcelService {
  const ExcelService(this._database);

  final AppDatabase _database;

  Future<File> exportToFile({required String yearMonth}) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}exports',
    );
    await exportDirectory.create(recursive: true);
    final file = File(
      '${exportDirectory.path}${Platform.pathSeparator}qingsongban_$yearMonth.xlsx',
    );
    await file.writeAsBytes(await exportBytes(yearMonth: yearMonth));
    return file;
  }

  Future<Uint8List> exportBytes({required String yearMonth}) async {
    AppDateUtils.parseYearMonth(yearMonth);
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    await _writePeopleSheet(excel['人员名单']);
    await _writeAttendanceSheet(excel['月考勤表'], yearMonth);
    await _writeSummarySheet(excel['月度汇总'], yearMonth);
    await _writeLeaveSheet(excel['请假明细'], yearMonth);
    await _writeOvertimeSheet(excel['加班明细'], yearMonth);
    await _writeTerminationSheet(excel['离职记录']);
    await _writeTerminationSheet(excel['人员变动']);
    await _writeInsuranceSheet(excel['保险变更'], yearMonth);

    final encoded = excel.encode();
    if (encoded == null) throw StateError('Excel 文件生成失败');
    return Uint8List.fromList(encoded);
  }

  Future<PersonnelImportPreview> previewPersonnelImport(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet =
        excel.tables['人员名单'] ??
        (excel.tables.isEmpty ? null : excel.tables.values.first);
    if (sheet == null || sheet.rows.isEmpty) {
      return const PersonnelImportPreview(
        rows: [],
        issues: [PersonnelImportIssue(rowNumber: 1, message: '未找到人员名单工作表')],
      );
    }
    final headerRow = sheet.rows.first;
    final headers = <String, int>{};
    for (var index = 0; index < headerRow.length; index++) {
      final header = _cellText(headerRow[index]).replaceAll(' ', '');
      if (header.isNotEmpty) headers[header] = index;
    }
    if (!headers.containsKey('姓名')) {
      return const PersonnelImportPreview(
        rows: [],
        issues: [PersonnelImportIssue(rowNumber: 1, message: '缺少必填列：姓名')],
      );
    }

    final groups =
        await (_database.select(_database.attendanceGroups)..where(
              (table) =>
                  table.isDeleted.equals(false) & table.isEnabled.equals(true),
            ))
            .get();
    final groupsByName = <String, AttendanceGroup>{
      for (final group in groups) group.name.trim().toLowerCase(): group,
    };
    final existingEmployees = await (_database.select(
      _database.employees,
    )..where((table) => table.isDeleted.equals(false))).get();
    final existingIds = <String>{
      for (final employee in existingEmployees)
        if ((employee.idCardNumber ?? '').trim().isNotEmpty)
          employee.idCardNumber!.trim().toLowerCase(),
    };
    final existingPhones = <String>{
      for (final employee in existingEmployees)
        if ((employee.phone ?? '').trim().isNotEmpty) employee.phone!.trim(),
    };
    final existingNumbers = <String>{
      for (final employee in existingEmployees)
        employee.employeeNo.toLowerCase(),
    };
    final rows = <PersonnelImportRow>[];
    final issues = <PersonnelImportIssue>[];
    final fileIds = <String>{};
    final filePhones = <String>{};
    final fileNumbers = <String>{};
    var generatedNumber = existingEmployees.length + 1;

    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex];
      if (row.every((cell) => _cellText(cell).trim().isEmpty)) continue;
      final rowNumber = rowIndex + 1;
      final name = _value(row, headers['姓名']).trim();
      final hireDate = _parseDate(_value(row, headers['入职日期']));
      final idCard = _nullable(_value(row, headers['身份证号']));
      final phone = _nullable(_value(row, headers['手机号']));
      var employeeNo = _nullable(_value(row, headers['工号'])) ?? '';
      if (employeeNo.isEmpty) {
        do {
          employeeNo = 'EMP-${generatedNumber.toString().padLeft(4, '0')}';
          generatedNumber++;
        } while (existingNumbers.contains(employeeNo.toLowerCase()) ||
            fileNumbers.contains(employeeNo.toLowerCase()));
      }
      final rowIssues = <String>[];
      if (name.isEmpty) rowIssues.add('姓名不能为空');
      if (hireDate == null) rowIssues.add('入职日期不能为空且须为 YYYY-MM-DD');
      if (idCard != null && !_isValidIdCard(idCard)) {
        rowIssues.add('身份证号格式不正确');
      }
      if (idCard != null &&
          (existingIds.contains(idCard.toLowerCase()) ||
              !fileIds.add(idCard.toLowerCase()))) {
        rowIssues.add('身份证号重复');
      }
      if (phone != null &&
          (existingPhones.contains(phone) || !filePhones.add(phone))) {
        rowIssues.add('手机号重复');
      }
      if (existingNumbers.contains(employeeNo.toLowerCase()) ||
          !fileNumbers.add(employeeNo.toLowerCase())) {
        rowIssues.add('工号重复');
      }
      final groupName = _nullable(_value(row, headers['默认考勤组']));
      final group = groupName == null
          ? null
          : groupsByName[groupName.toLowerCase()];
      if (groupName != null && group == null) {
        rowIssues.add('默认考勤组不存在或已停用');
      }
      if (rowIssues.isNotEmpty || hireDate == null) {
        issues.add(
          PersonnelImportIssue(
            rowNumber: rowNumber,
            message: rowIssues.join('；'),
          ),
        );
        continue;
      }
      rows.add(
        PersonnelImportRow(
          employeeNo: employeeNo,
          name: name,
          hireDate: hireDate,
          gender: _nullable(_value(row, headers['性别'])),
          idCardNumber: idCard,
          birthDate: _parseDate(_value(row, headers['出生日期'])),
          phone: phone,
          position: _nullable(_value(row, headers['岗位'])),
          team: _nullable(_value(row, headers['班组'])),
          workArea: _nullable(_value(row, headers['工作区域'])),
          manager: _nullable(_value(row, headers['负责人'])),
          employmentType: _nullable(_value(row, headers['用工类型'])),
          attendanceGroupId: group?.id,
          remark: _nullable(_value(row, headers['备注'])),
          isInsured: _value(row, headers['是否参保']) == '是',
        ),
      );
    }
    return PersonnelImportPreview(rows: rows, issues: issues);
  }

  Future<int> importPersonnel(PersonnelImportPreview preview) async {
    if (!preview.canImport) throw StateError('导入文件存在校验问题，请修正后重试');
    var count = 0;
    await _database.transaction(() async {
      for (final row in preview.rows) {
        final now = DateTime.now();
        final employeeId = await _database
            .into(_database.employees)
            .insert(
              EmployeesCompanion.insert(
                employeeNo: row.employeeNo,
                name: row.name,
                gender: Value(row.gender),
                idCardNumber: Value(row.idCardNumber),
                birthDate: Value(row.birthDate),
                phone: Value(row.phone),
                hireDate: row.hireDate,
                status: const Value(EmployeeStatus.active),
                position: Value(row.position),
                team: Value(row.team),
                workArea: Value(row.workArea),
                manager: Value(row.manager),
                employmentType: Value(row.employmentType),
                defaultAttendanceGroupId: Value(row.attendanceGroupId),
                remark: Value(row.remark),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        if (row.attendanceGroupId != null) {
          await _database
              .into(_database.attendanceGroupMembers)
              .insert(
                AttendanceGroupMembersCompanion.insert(
                  attendanceGroupId: row.attendanceGroupId!,
                  employeeId: employeeId,
                  isDefault: const Value(true),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
        count++;
      }
    });
    return count;
  }

  Future<void> _writePeopleSheet(Sheet sheet) async {
    sheet.appendRow(
      _row([
        '工号',
        '姓名',
        '性别',
        '身份证号',
        '出生日期',
        '手机号',
        '入职日期',
        '岗位',
        '班组',
        '工作区域',
        '负责人',
        '用工类型',
        '默认考勤组',
        '人员状态',
        '备注',
      ]),
    );
    final employees =
        await (_database.select(_database.employees)
              ..where((table) => table.isDeleted.equals(false))
              ..orderBy([(table) => OrderingTerm(expression: table.name)]))
            .get();
    final groups = await _database.select(_database.attendanceGroups).get();
    final groupsById = {for (final group in groups) group.id: group.name};
    for (final employee in employees) {
      sheet.appendRow(
        _row([
          employee.employeeNo,
          employee.name,
          employee.gender,
          employee.idCardNumber,
          employee.birthDate,
          employee.phone,
          employee.hireDate,
          employee.position,
          employee.team,
          employee.workArea,
          employee.manager,
          employee.employmentType,
          employee.defaultAttendanceGroupId == null
              ? null
              : groupsById[employee.defaultAttendanceGroupId],
          _employeeStatusLabel(employee.status),
          employee.remark,
        ]),
      );
    }
  }

  Future<void> _writeAttendanceSheet(Sheet sheet, String yearMonth) async {
    sheet.appendRow(_row(['日期', '工号', '姓名', '上午', '下午', '备注']));
    final start = AppDateUtils.parseYearMonth(yearMonth);
    final end = DateTime(start.year, start.month + 1);
    final employees = await _database.select(_database.employees).get();
    final byId = {for (final employee in employees) employee.id: employee};
    final records =
        await (_database.select(_database.attendanceRecords)
              ..where(
                (table) =>
                    table.attendanceDate.isBiggerOrEqualValue(start) &
                    table.attendanceDate.isSmallerThanValue(end) &
                    table.isDeleted.equals(false),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.attendanceDate),
              ]))
            .get();
    for (final record in records) {
      final employee = byId[record.employeeId];
      if (employee == null) continue;
      sheet.appendRow(
        _row([
          record.attendanceDate,
          employee.employeeNo,
          employee.name,
          record.morningStatus.name,
          record.afternoonStatus.name,
          record.remark,
        ]),
      );
    }
  }

  Future<void> _writeSummarySheet(Sheet sheet, String yearMonth) async {
    sheet.appendRow(
      _row([
        '工号',
        '姓名',
        '考勤天数',
        '请假天数',
        '缺勤天数',
        '休息天数',
        '停工天数',
        '加班次数',
        '加班分钟',
        '状态',
        '异常数',
      ]),
    );
    final employees = await _database.select(_database.employees).get();
    final byId = {for (final employee in employees) employee.id: employee};
    final rows =
        await (_database.select(_database.monthlyAttendanceSummaries)..where(
              (table) =>
                  table.yearMonth.equals(yearMonth) &
                  table.isDeleted.equals(false),
            ))
            .get();
    for (final row in rows) {
      final employee = byId[row.employeeId];
      if (employee == null) continue;
      sheet.appendRow(
        _row([
          employee.employeeNo,
          employee.name,
          row.attendanceDays,
          row.leaveDays,
          row.absentDays,
          row.restDays,
          row.stoppedDays,
          row.overtimeCount,
          row.overtimeMinutes,
          row.status.name,
          row.anomalyCount,
        ]),
      );
    }
  }

  Future<void> _writeLeaveSheet(Sheet sheet, String yearMonth) async {
    sheet.appendRow(
      _row(['工号', '姓名', '请假类型', '开始日期', '结束日期', '开始时段', '结束时段', '备注']),
    );
    final start = AppDateUtils.parseYearMonth(yearMonth);
    final end = DateTime(start.year, start.month + 1);
    final employees = await _database.select(_database.employees).get();
    final byId = {for (final employee in employees) employee.id: employee};
    final records =
        await (_database.select(_database.leaveRecords)..where(
              (table) =>
                  table.startDate.isSmallerThanValue(end) &
                  table.endDate.isBiggerOrEqualValue(start) &
                  table.isDeleted.equals(false),
            ))
            .get();
    for (final record in records) {
      final employee = byId[record.employeeId];
      if (employee == null) continue;
      sheet.appendRow(
        _row([
          employee.employeeNo,
          employee.name,
          record.leaveType.name,
          record.startDate,
          record.endDate,
          record.startPeriod.name,
          record.endPeriod.name,
          record.remark,
        ]),
      );
    }
  }

  Future<void> _writeOvertimeSheet(Sheet sheet, String yearMonth) async {
    sheet.appendRow(
      _row([
        '工号',
        '姓名',
        '日期',
        '开始时间',
        '结束时间',
        '分钟',
        '类型',
        '工作内容',
        '地点',
        '登记人',
        '备注',
      ]),
    );
    final start = AppDateUtils.parseYearMonth(yearMonth);
    final end = DateTime(start.year, start.month + 1);
    final employees = await _database.select(_database.employees).get();
    final byId = {for (final employee in employees) employee.id: employee};
    final records =
        await (_database.select(_database.overtimeRecords)..where(
              (table) =>
                  table.overtimeDate.isBiggerOrEqualValue(start) &
                  table.overtimeDate.isSmallerThanValue(end) &
                  table.isDeleted.equals(false),
            ))
            .get();
    for (final record in records) {
      final employee = byId[record.employeeId];
      if (employee == null) continue;
      sheet.appendRow(
        _row([
          employee.employeeNo,
          employee.name,
          record.overtimeDate,
          record.startTime,
          record.endTime,
          record.durationMinutes,
          record.overtimeType,
          record.workContent,
          record.workLocation,
          record.registrant,
          record.remark,
        ]),
      );
    }
  }

  Future<void> _writeTerminationSheet(Sheet sheet) async {
    sheet.appendRow(
      _row([
        '工号',
        '姓名',
        '离职日期',
        '离职类型',
        '已停保',
        '停保月份',
        '工具归还',
        '材料移交',
        '未结事项',
        '备注',
      ]),
    );
    final employees = await _database.select(_database.employees).get();
    final byId = {for (final employee in employees) employee.id: employee};
    final records = await (_database.select(
      _database.terminationRecords,
    )..where((table) => table.isDeleted.equals(false))).get();
    for (final record in records) {
      final employee = byId[record.employeeId];
      if (employee == null) continue;
      sheet.appendRow(
        _row([
          employee.employeeNo,
          employee.name,
          record.terminationDate,
          record.terminationType,
          record.isInsuranceStopped ? '是' : '否',
          record.stopInsuranceMonth,
          record.toolsReturned ? '是' : '否',
          record.materialsTransferred ? '是' : '否',
          record.hasUnsettledItems ? '是' : '否',
          record.remark,
        ]),
      );
    }
  }

  Future<void> _writeInsuranceSheet(Sheet sheet, String yearMonth) async {
    sheet.appendRow(
      _row(['工号', '姓名', '变更类型', '办理状态', '保险类型', '缴费基数', '生效月份', '备注']),
    );
    final employees = await _database.select(_database.employees).get();
    final byId = {for (final employee in employees) employee.id: employee};
    final records =
        await (_database.select(_database.insuranceChangeRecords)..where(
              (table) =>
                  table.effectiveMonth.equals(yearMonth) &
                  table.isDeleted.equals(false),
            ))
            .get();
    for (final record in records) {
      final employee = byId[record.employeeId];
      if (employee == null) continue;
      sheet.appendRow(
        _row([
          employee.employeeNo,
          employee.name,
          record.changeType,
          record.processingStatus,
          record.insuranceType,
          record.contributionBase,
          record.effectiveMonth,
          record.remark,
        ]),
      );
    }
  }

  List<CellValue?> _row(List<Object?> values) {
    return values.map(_cell).toList();
  }

  CellValue? _cell(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return DateTimeCellValue.fromDateTime(value);
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value.toString());
  }

  String _value(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return '';
    return _cellText(row[index]);
  }

  String _cellText(Data? data) {
    final value = data?.value;
    return switch (value) {
      null => '',
      TextCellValue value => value.value.text ?? '',
      IntCellValue value => value.value.toString(),
      DoubleCellValue value => value.value.toString(),
      BoolCellValue value => value.value ? '是' : '否',
      DateCellValue value => AppDateUtils.formatDate(value.asDateTimeLocal()),
      DateTimeCellValue value => _formatDateTime(value.asDateTimeLocal()),
      _ => value.toString(),
    };
  }

  DateTime? _parseDate(String value) {
    final normalized = value.trim().replaceAll('/', '-');
    if (normalized.isEmpty) return null;
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$')
        .firstMatch(normalized);
    if (match == null) return null;
    final parsed = DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    if (AppDateUtils.formatDate(parsed) !=
        '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}') {
      return null;
    }
    return parsed;
  }

  bool _isValidIdCard(String value) {
    return RegExp(r'^(\d{15}|\d{17}[\dXx])$').hasMatch(value);
  }

  String? _nullable(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _formatDateTime(DateTime value) {
    final date = AppDateUtils.formatDate(value);
    return '$date ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _employeeStatusLabel(EmployeeStatus status) {
    return PersonnelOptions.statusLabel(status);
  }
}
