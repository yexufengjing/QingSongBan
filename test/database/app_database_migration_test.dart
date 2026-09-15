import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';

void main() {
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
      expect(upgraded.schemaVersion, 11);
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
}

int _unixSeconds(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;
