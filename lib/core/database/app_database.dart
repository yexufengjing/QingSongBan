import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/native.dart';

import '../constants/database_constants.dart';
import '../utils/date_utils.dart';
import 'database_enums.dart';
import 'database_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Employees,
    Vehicles,
    VehicleConditionSnapshots,
    VehicleConditionItems,
    Tires,
    TireInstallations,
    TireRepairs,
    RepairOrders,
    RepairCostItems,
    RepairParts,
    VehicleAttachments,
    MaintenanceTemplates,
    VehicleMaintenanceItems,
    MaintenanceRecords,
    ComponentLifecycleRecords,
    FuelMonthlyRecords,
    ManualVehicleExpenses,
    WageJobTypes,
    WageRateHistory,
    EmployeeWageProfiles,
    PayrollBatches,
    PayrollItems,
    PayrollAdjustments,
    EmployeeAttachments,
    AttendanceGroups,
    AttendanceGroupMembers,
    MonthlyAttendanceRosters,
    AttendanceRecords,
    LeaveRecords,
    OvertimeRecords,
    TerminationRecords,
    MonthlyAttendanceSummaries,
    InsuranceProfiles,
    InsuranceChangeRecords,
    SocialSecurityBaseHistory,
    OperationLogs,
    DictionaryItems,
    AppSettings,
    Reminders,
    ReminderOccurrences,
    ReminderAlertRules,
    ReminderLinks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: DatabaseConstants.databaseName));

  /// In-memory database for repository and migration tests.
  AppDatabase.forTesting({QueryExecutor? executor})
    : super(executor ?? NativeDatabase.memory());

  @override
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createItemDistributionTables();
    },
    onUpgrade: (m, from, to) async {
      // Version 1 is the initial schema. Version 2 adds independent leave
      // records while retaining all existing attendance data.
      if (from < 1 && to >= 1) {
        await m.createAll();
      }
      if (from < 2 && to >= 2) {
        await m.createTable(leaveRecords);
      }
      if (from < 3 && to >= 3) {
        await m.createTable(overtimeRecords);
      }
      if (from < 4 && to >= 4) {
        await m.createTable(terminationRecords);
      }
      if (from < 5 && to >= 5) {
        await m.createTable(monthlyAttendanceSummaries);
      }
      if (from < 6 && to >= 6) {
        await m.createTable(insuranceProfiles);
        await m.createTable(insuranceChangeRecords);
        await m.createTable(socialSecurityBaseHistory);
      }
      if (from < 7 && to >= 7) {
        await m.createTable(reminders);
      }
      if (from < 8 && to >= 8) {
        await m.createTable(employeeAttachments);
      }
      if (from < 9 && to >= 9) {
        await m.createTable(wageJobTypes);
        await m.createTable(wageRateHistory);
        await m.createTable(employeeWageProfiles);
        await m.createTable(payrollBatches);
        await m.createTable(payrollItems);
        await m.createTable(payrollAdjustments);
      }
      if (from < 10 && to >= 10) {
        await _createItemDistributionTables();
      }
      if (from < 11 && to >= 11) {
        await _addColumnIfMissing(
          'item_distribution_entries',
          'welfare_position',
          'TEXT',
        );
        await _addColumnIfMissing(
          'item_distribution_entries',
          'actual_distribution_month',
          'TEXT',
        );
        await _addColumnIfMissing(
          'item_distribution_entries',
          'standard_quantity',
          'REAL',
        );
      }
      if (from < 12 && to >= 12) {
        if (await _tableExists('reminders')) {
          await _addColumnIfMissing(
            'reminders',
            'priority',
            "TEXT NOT NULL DEFAULT 'normal'",
          );
          await _addColumnIfMissing(
            'reminders',
            'category',
            "TEXT NOT NULL DEFAULT 'general'",
          );
          await _addColumnIfMissing(
            'reminders',
            'repeat_mode',
            "TEXT NOT NULL DEFAULT 'fixedSchedule'",
          );
          await _addColumnIfMissing('reminders', 'repeat_ends_at', 'INTEGER');
          await _addColumnIfMissing('reminders', 'repeat_count', 'INTEGER');
          await _addColumnIfMissing('reminders', 'timezone_id', 'TEXT');
          await _addColumnIfMissing('reminders', 'archived_at', 'INTEGER');
        } else {
          // Some older test/partial export files omit optional feature tables;
          // create the current table instead of attempting ALTER TABLE on it.
          await m.createTable(reminders);
        }
        await m.createTable(reminderOccurrences);
        await m.createTable(reminderAlertRules);
        await m.createTable(reminderLinks);
        await _migrateLegacyReminders();
      }
      if (from < 13 && to >= 13) {
        await m.createTable(vehicles);
      }
      if (from < 14 && to >= 14) {
        await m.createTable(vehicleConditionSnapshots);
        await m.createTable(vehicleConditionItems);
        await m.createTable(tires);
        await m.createTable(tireInstallations);
        await m.createTable(tireRepairs);
      }
      if (from < 15 && to >= 15) {
        await m.createTable(repairOrders);
        await m.createTable(repairCostItems);
        await m.createTable(repairParts);
        await m.createTable(vehicleAttachments);
      }
      if (from < 16 && to >= 16) {
        await m.createTable(maintenanceTemplates);
        await m.createTable(vehicleMaintenanceItems);
        await m.createTable(maintenanceRecords);
        await m.createTable(componentLifecycleRecords);
      }
      if (from < 17 && to >= 17) {
        await m.createTable(fuelMonthlyRecords);
        await m.createTable(manualVehicleExpenses);
      }
      if (from < 18 && to >= 18) {
        await _addColumnIfMissing(
          'vehicle_attachments',
          'stored_file_name',
          "TEXT NOT NULL DEFAULT ''",
        );
        await _addColumnIfMissing('vehicle_attachments', 'mime_type', 'TEXT');
        await _addColumnIfMissing('vehicle_attachments', 'file_hash', 'TEXT');
        await _addColumnIfMissing(
          'vehicle_attachments',
          'deleted_at',
          'INTEGER',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createItemDistributionTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS item_distribution_batches (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        benefit_month TEXT NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_item_distribution_batches_month
      ON item_distribution_batches(benefit_month, category, is_deleted)
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS item_distribution_entries (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        recipient_type TEXT NOT NULL,
        recipient_key TEXT NOT NULL,
        employee_id INTEGER,
        recipient_name TEXT NOT NULL,
        employment_type TEXT,
        welfare_position TEXT,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        standard_quantity REAL,
        unit TEXT NOT NULL DEFAULT '件',
        status TEXT NOT NULL DEFAULT 'not_received',
        signed_at TEXT,
        actual_distribution_month TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(batch_id) REFERENCES item_distribution_batches(id),
        FOREIGN KEY(employee_id) REFERENCES employees(id),
        UNIQUE(batch_id, recipient_type, recipient_key, item_code)
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_item_distribution_entries_recipient
      ON item_distribution_entries(recipient_key, status, is_deleted)
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS item_distribution_settings (
        setting_key TEXT NOT NULL PRIMARY KEY,
        setting_value TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO item_distribution_settings(setting_key, setting_value, updated_at)
      VALUES ('distribution.sweeper_count', '6', CURRENT_TIMESTAMP)
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO item_distribution_settings(setting_key, setting_value, updated_at)
      VALUES ('distribution.public_count', '1', CURRENT_TIMESTAMP)
    ''');
  }

  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String definition,
  ) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    if (columns.any((row) => row.data['name'] == column)) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<bool> _tableExists(String table) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(table)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> _migrateLegacyReminders() async {
    // Existing v7-v11 reminders are preserved as a series owner, its first
    // execution (when a due date exists), and one equivalent lead-time rule.
    // INSERT OR IGNORE makes the migration safe if a partially upgraded file
    // is opened again.
    await customStatement('''
      INSERT OR IGNORE INTO reminder_occurrences
        (reminder_id, scheduled_at, status, completed_at, created_at, updated_at)
      SELECT id,
             due_date,
             CASE WHEN is_completed = 1 THEN 'completed' ELSE 'pending' END,
             CASE WHEN is_completed = 1 THEN updated_at ELSE NULL END,
             created_at,
             updated_at
      FROM reminders
      WHERE due_date IS NOT NULL AND is_deleted = 0
    ''');
    await customStatement('''
      INSERT INTO reminder_alert_rules
        (reminder_id, offset_minutes, is_nag_rule, sort_order, is_enabled,
         created_at, updated_at)
      SELECT r.id, r.lead_days * -1440, 0, 0, r.is_enabled,
             r.created_at, r.updated_at
      FROM reminders r
      WHERE NOT EXISTS (
        SELECT 1 FROM reminder_alert_rules a WHERE a.reminder_id = r.id
      )
    ''');
  }

  Future<int> insertEmployee(EmployeesCompanion employee) {
    return into(employees).insert(employee);
  }

  Future<Employee?> findEmployeeById(int id) {
    return (select(
      employees,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<List<Employee>> listEmployees({bool includeDeleted = false}) {
    final query = select(employees)
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.get();
  }

  Stream<List<Employee>> watchEmployees({bool includeDeleted = false}) {
    final query = select(employees)
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.watch();
  }

  Future<int> softDeleteEmployee(int id) {
    return (update(employees)..where((table) => table.id.equals(id))).write(
      EmployeesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restoreEmployee(int id) {
    return (update(employees)..where((table) => table.id.equals(id))).write(
      EmployeesCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<AttendanceRecord?> findAttendanceRecord(
    int employeeId,
    DateTime attendanceDate,
  ) {
    final date = AppDateUtils.dateOnly(attendanceDate);
    return (select(attendanceRecords)..where(
          (table) =>
              table.employeeId.equals(employeeId) &
              table.attendanceDate.equals(date),
        ))
        .getSingleOrNull();
  }
}
