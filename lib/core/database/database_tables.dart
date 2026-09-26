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

class Vehicles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get vehicleNo => text().unique()();

  TextColumn get licensePlate => text().nullable().unique()();

  TextColumn get vehicleType =>
      textEnum<VehicleType>().withDefault(const Constant('sweeper'))();

  TextColumn get brand => text().nullable()();

  TextColumn get model => text().nullable()();

  DateTimeColumn get purchaseDate => dateTime().nullable()();

  TextColumn get department => text().nullable()();

  TextColumn get workArea => text().nullable()();

  TextColumn get responsiblePerson => text().nullable()();

  TextColumn get status =>
      textEnum<VehicleStatus>().withDefault(const Constant('normal'))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class VehicleConditionSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  DateTimeColumn get checkedAt => dateTime()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class VehicleConditionItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  IntColumn get snapshotId =>
      integer().nullable().references(VehicleConditionSnapshots, #id)();

  TextColumn get componentType => text()();

  TextColumn get componentKey => text()();

  TextColumn get status => textEnum<VehicleConditionStatus>()();

  TextColumn get issueTagsJson => text().nullable()();

  TextColumn get detail => text().nullable()();

  DateTimeColumn get observedAt => dateTime()();

  DateTimeColumn get resolvedAt => dateTime().nullable()();

  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class Tires extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get tireNo => text().unique()();

  TextColumn get brand => text().nullable()();

  TextColumn get specification => text().nullable()();

  TextColumn get condition =>
      textEnum<TireCondition>().withDefault(const Constant('newTire'))();

  DateTimeColumn get firstUseDate => dateTime().nullable()();

  TextColumn get status =>
      textEnum<TireAssetStatus>().withDefault(const Constant('spare'))();

  IntColumn get repairCount => integer().withDefault(const Constant(0))();

  TextColumn get wearLevel =>
      textEnum<TireWearLevel>().withDefault(const Constant('good'))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class TireInstallations extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get tireId => integer().references(Tires, #id)();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  TextColumn get position => textEnum<TirePosition>()();

  DateTimeColumn get installDate => dateTime()();

  DateTimeColumn get removeDate => dateTime().nullable()();

  TextColumn get installReason => textEnum<TireInstallReason>()();

  TextColumn get removeReason => text().nullable()();

  TextColumn get sourcePosition => text().nullable()();

  TextColumn get note => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class TireRepairs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get tireId => integer().references(Tires, #id)();

  DateTimeColumn get repairDate => dateTime()();

  TextColumn get repairType => textEnum<TireRepairType>()();

  TextColumn get repairPosition => text().nullable()();

  TextColumn get severity => textEnum<TireRepairSeverity>()();

  IntColumn get amountCents => integer().withDefault(const Constant(0))();

  TextColumn get vendor => text().nullable()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class RepairOrders extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get repairNo => text().unique()();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  DateTimeColumn get reportDate => dateTime()();

  DateTimeColumn get faultFoundAt => dateTime()();

  TextColumn get symptom => text()();

  TextColumn get cause => text().nullable()();

  TextColumn get project => text().nullable()();

  DateTimeColumn get departAt => dateTime().nullable()();

  TextColumn get vendor => text().nullable()();

  TextColumn get manager => text().nullable()();

  IntColumn get reportedAmountCents =>
      integer().withDefault(const Constant(0))();

  IntColumn get actualAmountCents => integer().withDefault(const Constant(0))();

  TextColumn get ticketStatus => textEnum<RepairTicketStatus>()();

  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();

  DateTimeColumn get settledAt => dateTime().nullable()();

  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();

  DateTimeColumn get paidAt => dateTime().nullable()();

  TextColumn get status =>
      textEnum<VehicleRepairStatus>().withDefault(const Constant('reported'))();

  DateTimeColumn get completedAt => dateTime().nullable()();

  TextColumn get recordText => text().nullable()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class RepairCostItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get repairOrderId => integer().references(RepairOrders, #id)();

  TextColumn get content => text()();

  RealColumn get quantity => real().withDefault(const Constant(1.0))();

  TextColumn get unit => text().withDefault(const Constant('项'))();

  IntColumn get unitPriceCents => integer()();

  IntColumn get subtotalCents => integer()();

  TextColumn get costType => textEnum<RepairCostType>()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class RepairParts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get repairOrderId => integer().references(RepairOrders, #id)();

  IntColumn get costItemId =>
      integer().nullable().references(RepairCostItems, #id)();

  IntColumn get tireId => integer().nullable().references(Tires, #id)();

  TextColumn get name => text()();

  RealColumn get quantity => real().withDefault(const Constant(1.0))();

  TextColumn get unit => text().withDefault(const Constant('件'))();

  IntColumn get amountCents => integer().withDefault(const Constant(0))();

  TextColumn get componentType => text().nullable()();

  TextColumn get remark => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class VehicleAttachments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  IntColumn get repairOrderId =>
      integer().nullable().references(RepairOrders, #id)();

  TextColumn get category => text().withDefault(const Constant('other'))();

  TextColumn get originalFileName => text()();

  TextColumn get storedFileName => text().withDefault(const Constant(''))();

  TextColumn get relativePath => text().unique()();

  TextColumn get mimeType => text().nullable()();

  TextColumn get extension => text()();

  IntColumn get fileSize => integer()();

  TextColumn get fileHash => text().nullable()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class MaintenanceTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get componentType => text().nullable()();

  IntColumn get intervalValue => integer()();

  TextColumn get intervalUnit => textEnum<MaintenanceIntervalUnit>()();

  IntColumn get leadDays => integer().withDefault(const Constant(30))();

  IntColumn get overdueDays => integer().withDefault(const Constant(15))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class VehicleMaintenanceItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  IntColumn get templateId =>
      integer().nullable().references(MaintenanceTemplates, #id)();

  TextColumn get name => text()();

  TextColumn get componentType => text().nullable()();

  IntColumn get intervalValue => integer()();

  TextColumn get intervalUnit => textEnum<MaintenanceIntervalUnit>()();

  IntColumn get leadDays => integer().withDefault(const Constant(30))();

  IntColumn get overdueDays => integer().withDefault(const Constant(15))();

  DateTimeColumn get lastServiceDate => dateTime().nullable()();

  DateTimeColumn get nextDueDate => dateTime().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class MaintenanceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get maintenanceItemId =>
      integer().references(VehicleMaintenanceItems, #id)();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  DateTimeColumn get serviceDate => dateTime()();

  IntColumn get materialCostCents => integer().withDefault(const Constant(0))();

  IntColumn get laborCostCents => integer().withDefault(const Constant(0))();

  IntColumn get totalCostCents => integer().withDefault(const Constant(0))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class ComponentLifecycleRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  TextColumn get componentType => text()();

  TextColumn get componentKey => text()();

  TextColumn get name => text()();

  DateTimeColumn get installedDate => dateTime()();

  DateTimeColumn get removedDate => dateTime().nullable()();

  TextColumn get status =>
      textEnum<LifecycleStatus>().withDefault(const Constant('inUse'))();

  IntColumn get thresholdDays => integer().nullable()();

  DateTimeColumn get lastServiceDate => dateTime().nullable()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class FuelMonthlyRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  IntColumn get year => integer()();

  IntColumn get month => integer()();

  RealColumn get liters => real()();

  IntColumn get amountCents => integer()();

  IntColumn get workDays => integer().nullable()();

  RealColumn get workMileage => real().nullable()();

  RealColumn get workHours => real().nullable()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {vehicleId, year, month},
  ];
}

class ManualVehicleExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  DateTimeColumn get expenseDate => dateTime()();

  TextColumn get expenseType => text()();

  IntColumn get amountCents => integer()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class WageJobTypes extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  RealColumn get defaultDailyWage => real().withDefault(const Constant(0.0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class WageRateHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get jobTypeId => integer().references(WageJobTypes, #id)();

  RealColumn get dailyWage => real()();

  TextColumn get effectiveMonth => text()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {jobTypeId, effectiveMonth},
  ];
}

class EmployeeWageProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  BoolColumn get participatesInPayroll =>
      boolean().withDefault(const Constant(false))();

  IntColumn get jobTypeId =>
      integer().nullable().references(WageJobTypes, #id)();

  BoolColumn get useJobDefaultWage =>
      boolean().withDefault(const Constant(true))();

  RealColumn get personalDailyWage => real().nullable()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {employeeId},
  ];
}

class PayrollBatches extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get payrollMonth => text()();

  TextColumn get name => text()();

  TextColumn get status =>
      textEnum<PayrollStatus>().withDefault(const Constant('draft'))();

  TextColumn get attendanceSnapshotVersion => text().nullable()();

  IntColumn get employeeCount => integer().withDefault(const Constant(0))();

  IntColumn get attendanceHalfDaysTotal =>
      integer().withDefault(const Constant(0))();

  RealColumn get baseWageTotal => real().withDefault(const Constant(0.0))();

  RealColumn get subsidyTotal => real().withDefault(const Constant(0.0))();

  RealColumn get insuranceDeductionTotal =>
      real().withDefault(const Constant(0.0))();

  RealColumn get finalWageTotal => real().withDefault(const Constant(0.0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get confirmedAt => dateTime().nullable()();

  DateTimeColumn get lockedAt => dateTime().nullable()();

  TextColumn get remark => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {payrollMonth},
  ];
}

class PayrollItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get payrollBatchId => integer().references(PayrollBatches, #id)();

  IntColumn get employeeId => integer().references(Employees, #id)();

  IntColumn get displayOrder => integer()();

  TextColumn get employeeNameSnapshot => text()();

  TextColumn get employeeNoSnapshot => text()();

  IntColumn get jobTypeId =>
      integer().nullable().references(WageJobTypes, #id)();

  TextColumn get jobTypeNameSnapshot => text().nullable()();

  IntColumn get attendanceHalfDaysSnapshot => integer()();

  RealColumn get dailyWage => real().withDefault(const Constant(0.0))();

  TextColumn get dailyWageSource =>
      text().withDefault(const Constant('none'))();

  RealColumn get baseWage => real().withDefault(const Constant(0.0))();

  RealColumn get subsidy => real().withDefault(const Constant(0.0))();

  RealColumn get insuranceDeduction =>
      real().withDefault(const Constant(0.0))();

  TextColumn get insuranceDeductionSource =>
      text().withDefault(const Constant('manual'))();

  RealColumn get finalWage => real().withDefault(const Constant(0.0))();

  BoolColumn get isManuallyAdded =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isManuallyRemoved =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get attendanceChanged =>
      boolean().withDefault(const Constant(false))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class PayrollAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get payrollItemId => integer().references(PayrollItems, #id)();

  TextColumn get type => text()();

  TextColumn get name => text()();

  RealColumn get amount => real()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Files copied into the app-private attachment directory. Only the relative
/// path is persisted so backups remain portable between devices.
class EmployeeAttachments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  TextColumn get sourceEntityType =>
      text().withDefault(const Constant('personnel'))();

  IntColumn get sourceEntityId => integer().nullable()();

  TextColumn get category => text().withDefault(const Constant('other'))();

  TextColumn get originalFileName => text()();

  TextColumn get relativePath => text().unique()();

  TextColumn get extension => text()();

  IntColumn get fileSize => integer()();

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

class LeaveRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  TextColumn get leaveType =>
      textEnum<LeaveType>().withDefault(const Constant('personal'))();

  /// Local calendar date of the first leave day.
  DateTimeColumn get startDate => dateTime()();

  /// Local calendar date of the last leave day.
  DateTimeColumn get endDate => dateTime()();

  /// Half-day boundary on [startDate].
  TextColumn get startPeriod =>
      textEnum<LeaveHalfPeriod>().withDefault(const Constant('morning'))();

  /// Half-day boundary on [endDate].
  TextColumn get endPeriod =>
      textEnum<LeaveHalfPeriod>().withDefault(const Constant('afternoon'))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class OvertimeRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  /// Local calendar date used by monthly overtime reports.
  DateTimeColumn get overtimeDate => dateTime()();

  /// Local date-time of the overtime start.
  DateTimeColumn get startTime => dateTime()();

  /// Local date-time of the overtime end.
  DateTimeColumn get endTime => dateTime()();

  IntColumn get durationMinutes => integer()();

  TextColumn get overtimeType =>
      text().withDefault(const Constant('weekday'))();

  TextColumn get workContent => text().nullable()();

  TextColumn get workLocation => text().nullable()();

  TextColumn get registrant => text().nullable()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class TerminationRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  DateTimeColumn get terminationDate => dateTime()();

  TextColumn get terminationType =>
      text().withDefault(const Constant('personal'))();

  BoolColumn get isInsuranceStopped =>
      boolean().withDefault(const Constant(false))();

  TextColumn get stopInsuranceMonth => text().nullable()();

  BoolColumn get toolsReturned =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get materialsTransferred =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get hasUnsettledItems =>
      boolean().withDefault(const Constant(false))();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Revoking a termination is represented by a soft delete.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class MonthlyAttendanceSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get yearMonth => text()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  IntColumn get attendanceGroupId =>
      integer().nullable().references(AttendanceGroups, #id)();

  BoolColumn get participates => boolean().withDefault(const Constant(true))();

  RealColumn get attendanceDays => real().withDefault(const Constant(0.0))();

  RealColumn get leaveDays => real().withDefault(const Constant(0.0))();

  RealColumn get absentDays => real().withDefault(const Constant(0.0))();

  RealColumn get restDays => real().withDefault(const Constant(0.0))();

  RealColumn get stoppedDays => real().withDefault(const Constant(0.0))();

  IntColumn get overtimeCount => integer().withDefault(const Constant(0))();

  IntColumn get overtimeMinutes => integer().withDefault(const Constant(0))();

  TextColumn get monthStartStatus => text().nullable()();

  TextColumn get monthEndStatus => text().nullable()();

  BoolColumn get joinedDuringMonth =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get terminatedDuringMonth =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isComplete => boolean().withDefault(const Constant(false))();

  IntColumn get anomalyCount => integer().withDefault(const Constant(0))();

  TextColumn get status => textEnum<MonthlySummaryStatus>().withDefault(
    const Constant('notGenerated'),
  )();

  DateTimeColumn get generatedAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {yearMonth, employeeId, attendanceGroupId},
  ];
}

class InsuranceProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  BoolColumn get isInsured => boolean().withDefault(const Constant(false))();

  TextColumn get insuranceType => text().nullable()();

  RealColumn get contributionBase => real().nullable()();

  TextColumn get effectiveMonth => text().nullable()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {employeeId},
  ];
}

class InsuranceChangeRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  TextColumn get changeType => text()();

  TextColumn get processingStatus =>
      text().withDefault(const Constant('pending'))();

  TextColumn get insuranceType => text().nullable()();

  RealColumn get contributionBase => real().nullable()();

  TextColumn get effectiveMonth => text()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class SocialSecurityBaseHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get employeeId => integer().references(Employees, #id)();

  TextColumn get insuranceType => text().nullable()();

  RealColumn get contributionBase => real().nullable()();

  TextColumn get effectiveMonth => text()();

  TextColumn get source => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
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

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get reminderType => text()();

  /// A stable, user-facing urgency value. Keep this as text so future values
  /// can be added without a destructive database migration.
  TextColumn get priority => text().withDefault(const Constant('normal'))();

  /// General/plan/personnel/etc. are domain categories, not notification
  /// implementations. Unknown values remain forward compatible.
  TextColumn get category => text().withDefault(const Constant('general'))();

  DateTimeColumn get dueDate => dateTime().nullable()();

  IntColumn get leadDays => integer().withDefault(const Constant(0))();

  TextColumn get repeatRule => text().nullable()();

  TextColumn get repeatMode =>
      text().withDefault(const Constant('fixedSchedule'))();

  DateTimeColumn get repeatEndsAt => dateTime().nullable()();

  IntColumn get repeatCount => integer().nullable()();

  TextColumn get timezoneId => text().nullable()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  TextColumn get sourceEntityType => text().nullable()();

  IntColumn get sourceEntityId => integer().nullable()();

  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

/// One planned execution of a reminder series. A recurring reminder never
/// mutates its previous occurrence; it creates a new row for each period.
class ReminderOccurrences extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get reminderId => integer().references(Reminders, #id)();

  DateTimeColumn get scheduledAt => dateTime()();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get snoozedUntil => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {reminderId, scheduledAt},
  ];
}

/// Relative notifications attached to a reminder. Negative offsets are
/// before due time; nag rules use a positive interval after due time.
class ReminderAlertRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get reminderId => integer().references(Reminders, #id)();

  IntColumn get offsetMinutes => integer().withDefault(const Constant(0))();

  BoolColumn get isNagRule => boolean().withDefault(const Constant(false))();

  IntColumn get repeatIntervalMinutes => integer().nullable()();

  IntColumn get maxRepeatCount => integer().nullable()();

  IntColumn get nagEndsAfterMinutes => integer().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Polymorphic links let reminders reference employees today and future
/// vehicle/equipment/material modules without inventing foreign keys.
class ReminderLinks extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get reminderId => integer().references(Reminders, #id)();

  TextColumn get entityType => text()();

  IntColumn get entityId => integer()();

  TextColumn get displayNameSnapshot => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {reminderId, entityType, entityId},
  ];
}
