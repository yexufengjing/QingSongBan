import 'package:drift/drift.dart';

import '../constants/database_constants.dart';
import 'database_enums.dart';

/// Employee master data. Attendance participation is intentionally stored in
/// [MonthlyAttendanceRosters], not inferred from [status].
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get employeeNo => text().unique()();

  TextColumn get name => text()();

  TextColumn get gender => text().nullable()();

  TextColumn get idCardNumber => text().nullable()();

  DateTimeColumn get birthDate => dateTime().nullable()();

  TextColumn get phone => text().nullable()();

  TextColumn get address => text().nullable()();

  DateTimeColumn get hireDate => dateTime()();

  TextColumn get status =>
      textEnum<EmployeeStatus>().withDefault(const Constant('active'))();

  TextColumn get position => text().nullable()();

  TextColumn get team => text().nullable()();

  TextColumn get workArea => text().nullable()();

  TextColumn get manager => text().nullable()();

  TextColumn get employmentType => text().nullable()();

  IntColumn get defaultAttendanceGroupId =>
      integer().nullable().references(AttendanceGroups, #id)();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class AttendanceGroups extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get groupType => text().withDefault(const Constant('manual'))();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class AttendanceGroupMembers extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get attendanceGroupId =>
      integer().references(AttendanceGroups, #id)();

  IntColumn get employeeId => integer().references(Employees, #id)();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {attendanceGroupId, employeeId},
  ];
}

class MonthlyAttendanceRosters extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stored as YYYY-MM so the month has no timezone ambiguity.
  TextColumn get yearMonth => text()();

  IntColumn get attendanceGroupId =>
      integer().references(AttendanceGroups, #id)();

  IntColumn get employeeId => integer().references(Employees, #id)();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  TextColumn get source => text().withDefault(
    const Constant(DatabaseConstants.manualRosterSource),
  )();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {yearMonth, attendanceGroupId, employeeId},
  ];
}

class AttendanceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  /// Callers should normalize this value to a local calendar date.
  DateTimeColumn get attendanceDate => dateTime()();

  TextColumn get morningStatus => textEnum<AttendanceHalfStatus>().withDefault(
    const Constant('unregistered'),
  )();

  TextColumn get afternoonStatus => textEnum<AttendanceHalfStatus>()
      .withDefault(const Constant('unregistered'))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {employeeId, attendanceDate},
  ];
}

class OperationLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get operationType => text()();

  TextColumn get entityType => text()();

  IntColumn get entityId => integer().nullable()();

  TextColumn get detail => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class DictionaryItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get dictionaryType => text()();

  TextColumn get itemKey => text()();

  TextColumn get itemLabel => text()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {dictionaryType, itemKey},
  ];
}

class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get settingKey => text().unique()();

  TextColumn get settingValue => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
