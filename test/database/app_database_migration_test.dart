import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';

void main() {
  test('creates missing garden repair tables while preserving a version twenty database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'qsb-v20-migration-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}legacy.sqlite',
    );
    final legacy = AppDatabase.forTesting(
      executor: NativeDatabase(
        file,
        enableMigrations: false,
        setup: (raw) {
          raw.execute('''
            CREATE TABLE repair_orders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              is_settled INTEGER NOT NULL DEFAULT 0,
              settled_at INTEGER,
              is_paid INTEGER NOT NULL DEFAULT 0,
              paid_at INTEGER
            )
          ''');
          raw.execute('INSERT INTO repair_orders(id) VALUES (1)');
          raw.execute('PRAGMA user_version = 20');
        },
      ),
    );
    await legacy.customSelect('PRAGMA user_version').get();
    await legacy.close();

    final upgraded = AppDatabase.forTesting(executor: NativeDatabase(file));
    final repairOrder = await upgraded
        .customSelect(
          'SELECT is_settled, is_paid FROM repair_orders WHERE id = 1',
        )
        .getSingle();

    expect(upgraded.schemaVersion, 21);
    expect(repairOrder.read<int>('is_settled'), 0);
    expect(repairOrder.read<int>('is_paid'), 0);
    expect(
      await upgraded.select(upgraded.gardenToolRepairUnits).get(),
      isEmpty,
    );
    expect(
      await upgraded.select(upgraded.gardenToolRepairPersons).get(),
      isEmpty,
    );
    expect(
      await upgraded.select(upgraded.gardenToolRepairGroups).get(),
      isEmpty,
    );
    expect(
      await upgraded.select(upgraded.gardenToolRepairItems).get(),
      isEmpty,
    );
    expect(
      await upgraded.select(upgraded.gardenToolRepairAttachments).get(),
      isEmpty,
    );
    await upgraded.close();
    await directory.delete(recursive: true);
  });

  test('adds settlement markers to existing repair orders in schema nineteen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'qsb-v19-migration-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}legacy.sqlite',
    );
    final legacy = AppDatabase.forTesting(
      executor: NativeDatabase(
        file,
        enableMigrations: false,
        setup: (raw) {
          raw.execute('''
            CREATE TABLE repair_orders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              repair_no TEXT NOT NULL UNIQUE,
              vehicle_id INTEGER NOT NULL,
              report_date INTEGER NOT NULL,
              fault_found_at INTEGER NOT NULL,
              symptom TEXT NOT NULL,
              cause TEXT,
              project TEXT,
              depart_at INTEGER,
              vendor TEXT,
              manager TEXT,
              reported_amount_cents INTEGER NOT NULL DEFAULT 0,
              actual_amount_cents INTEGER NOT NULL DEFAULT 0,
              ticket_status TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'reported',
              completed_at INTEGER,
              record_text TEXT,
              remark TEXT,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0,
              is_deleted INTEGER NOT NULL DEFAULT 0
            )
          ''');
          raw.execute('PRAGMA user_version = 19');
        },
      ),
    );
    await legacy.customStatement(
      'INSERT INTO repair_orders(repair_no, vehicle_id, report_date, '
      'fault_found_at, symptom, ticket_status) VALUES (?, ?, ?, ?, ?, ?)',
      ['R-001', 1, 0, 0, '故障', 'pending'],
    );
    await legacy.close();

    final upgraded = AppDatabase.forTesting(executor: NativeDatabase(file));
    final row = await upgraded
        .customSelect(
          'SELECT is_settled, settled_at, is_paid, paid_at FROM repair_orders',
        )
        .getSingle();

    expect(upgraded.schemaVersion, 21);
    expect(row.read<int>('is_settled'), 0);
    expect(row.read<int?>('settled_at'), isNull);
    expect(row.read<int>('is_paid'), 0);
    expect(row.read<int?>('paid_at'), isNull);
    await upgraded.close();
    await directory.delete(recursive: true);
  });

  test(
    'upgrades a schema eight database without losing personnel or attendance',
    () async {
      final directory = await Directory.systemTemp.createTemp('qsb-migration-');
      final file = File(
        '${directory.path}${Platform.pathSeparator}legacy.sqlite',
      );

      final legacy = AppDatabase.forTesting(
        executor: NativeDatabase(
          file,
          enableMigrations: false,
          setup: (raw) {
            raw.execute('''
            CREATE TABLE attendance_groups (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              group_type TEXT NOT NULL DEFAULT 'manual',
              is_enabled INTEGER NOT NULL DEFAULT 1,
              sort_order INTEGER NOT NULL DEFAULT 0,
              remark TEXT,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0,
              is_deleted INTEGER NOT NULL DEFAULT 0
            )
          ''');
            raw.execute('''
            CREATE TABLE employees (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              employee_no TEXT NOT NULL UNIQUE,
              name TEXT NOT NULL,
              gender TEXT,
              id_card_number TEXT,
              birth_date INTEGER,
              phone TEXT,
              address TEXT,
              hire_date INTEGER NOT NULL,
              status TEXT NOT NULL DEFAULT 'active',
              position TEXT,
              team TEXT,
              work_area TEXT,
              manager TEXT,
              employment_type TEXT,
              default_attendance_group_id INTEGER,
              remark TEXT,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0,
              is_deleted INTEGER NOT NULL DEFAULT 0
            )
          ''');
            raw.execute('''
            CREATE TABLE attendance_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              employee_id INTEGER NOT NULL,
              attendance_date INTEGER NOT NULL,
              morning_status TEXT NOT NULL DEFAULT 'unregistered',
              afternoon_status TEXT NOT NULL DEFAULT 'unregistered',
              remark TEXT,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              UNIQUE(employee_id, attendance_date)
            )
          ''');
            raw.execute('PRAGMA user_version = 8');
          },
        ),
      );
      await legacy.customStatement(
        'INSERT INTO employees(employee_no, name, hire_date) VALUES (?, ?, ?)',
        ['LEG-0001', '迁移人员', _unixSeconds(DateTime(2026, 9, 1))],
      );
      await legacy.customStatement(
        'INSERT INTO attendance_records(employee_id, attendance_date, morning_status) VALUES (?, ?, ?)',
        [1, _unixSeconds(DateTime(2026, 9, 1)), 'present'],
      );
      await legacy.close();

      final upgraded = AppDatabase.forTesting(executor: NativeDatabase(file));
      final employee = await upgraded.findEmployeeById(1);
      final rawAttendance = await upgraded
          .customSelect(
            'SELECT employee_id, attendance_date, morning_status FROM attendance_records',
          )
          .get();
      final attendance = await upgraded.findAttendanceRecord(
        1,
        DateTime(2026, 9, 1),
      );
      expect(upgraded.schemaVersion, 21);
      expect(await upgraded.select(upgraded.vehicles).get(), isEmpty);
      expect(
        await upgraded.select(upgraded.gardenToolRepairUnits).get(),
        isEmpty,
      );
      expect(
        await upgraded.select(upgraded.gardenToolRepairPersons).get(),
        isEmpty,
      );
      expect(
        await upgraded.select(upgraded.gardenToolRepairGroups).get(),
        isEmpty,
      );
      expect(
        await upgraded.select(upgraded.gardenToolRepairItems).get(),
        isEmpty,
      );
      expect(
        await upgraded.select(upgraded.gardenToolRepairAttachments).get(),
        isEmpty,
      );
      expect(employee?.name, '迁移人员');
      expect(rawAttendance, hasLength(1));
      expect(rawAttendance.single.read<int>('employee_id'), 1);
      expect(rawAttendance.single.read<String>('morning_status'), 'present');
      expect(attendance?.morningStatus.name, 'present');
      expect(await upgraded.select(upgraded.payrollBatches).get(), isEmpty);
      await upgraded.close();
      await directory.delete(recursive: true);
    },
  );

  test('migrates legacy reminders into occurrences and alert rules', () async {
    final directory = await Directory.systemTemp.createTemp(
      'qsb-reminder-migration-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}legacy.sqlite',
    );
    final legacy = AppDatabase.forTesting(
      executor: NativeDatabase(
        file,
        enableMigrations: false,
        setup: (raw) {
          raw.execute('''
          CREATE TABLE reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            reminder_type TEXT NOT NULL,
            due_date INTEGER,
            lead_days INTEGER NOT NULL DEFAULT 0,
            repeat_rule TEXT,
            is_enabled INTEGER NOT NULL DEFAULT 1,
            is_completed INTEGER NOT NULL DEFAULT 0,
            source_entity_type TEXT,
            source_entity_id INTEGER,
            remark TEXT,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
          raw.execute('PRAGMA user_version = 11');
        },
      ),
    );
    await legacy.customStatement(
      'INSERT INTO reminders(title, reminder_type, due_date, lead_days, is_completed, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['旧提醒', 'custom', _unixSeconds(DateTime(2026, 9, 20, 10)), 3, 1, 0, 0],
    );
    await legacy.close();

    final upgraded = AppDatabase.forTesting(executor: NativeDatabase(file));
    final occurrence = await upgraded
        .select(upgraded.reminderOccurrences)
        .getSingle();
    final rule = await upgraded.select(upgraded.reminderAlertRules).getSingle();
    expect(upgraded.schemaVersion, 21);
    expect(occurrence.status, 'completed');
    expect(rule.offsetMinutes, -4320);
    await upgraded.close();
    await directory.delete(recursive: true);
  });
}

int _unixSeconds(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;
