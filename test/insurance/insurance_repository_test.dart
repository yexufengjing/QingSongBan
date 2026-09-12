import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/insurance/data/insurance_repository.dart';
import 'package:qingsongban/features/insurance/domain/insurance_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  late AppDatabase database;
  late InsuranceRepository insuranceRepository;
  late PersonnelRepository personnelRepository;

  setUp(() {
    database = AppDatabase.forTesting();
    insuranceRepository = InsuranceRepository(database);
    personnelRepository = PersonnelRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Employee> createEmployee(String employeeNo, String name) {
    return personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: employeeNo,
        name: name,
        hireDate: DateTime(2026, 1, 1),
        status: EmployeeStatus.active,
      ),
    );
  }

  test('saves current insurance and records base history', () async {
    final employee = await createEmployee('EMP-I001', '张三');
    final profile = await insuranceRepository.saveProfile(
      draft: InsuranceProfileDraft(
        employeeId: employee.id,
        isInsured: true,
        insuranceType: 'employee',
        contributionBase: 5000,
        effectiveMonth: '2026-09',
      ),
    );

    expect(profile.isInsured, isTrue);
    expect(profile.contributionBase, 5000);
    expect(await insuranceRepository.watchProfiles().first, hasLength(1));
    expect(
      await (database.select(database.socialSecurityBaseHistory)).get(),
      hasLength(1),
    );
  });

  test('completed stop and restore changes current insurance', () async {
    final employee = await createEmployee('EMP-I101', '李四');
    await insuranceRepository.saveProfile(
      draft: InsuranceProfileDraft(
        employeeId: employee.id,
        isInsured: true,
        insuranceType: 'employee',
        contributionBase: 4500,
        effectiveMonth: '2026-08',
      ),
    );
    final stop = await insuranceRepository.saveChange(
      draft: InsuranceChangeDraft(
        employeeId: employee.id,
        changeType: 'stop',
        processingStatus: 'pending',
        effectiveMonth: '2026-09',
      ),
    );
    expect(
      (await insuranceRepository.findProfile(employee.id))?.isInsured,
      isTrue,
    );
    await insuranceRepository.updateChangeStatus(stop.id, 'completed');
    expect(
      (await insuranceRepository.findProfile(employee.id))?.isInsured,
      isFalse,
    );

    final restore = await insuranceRepository.saveChange(
      draft: InsuranceChangeDraft(
        employeeId: employee.id,
        changeType: 'restore',
        processingStatus: 'completed',
        effectiveMonth: '2026-10',
        insuranceType: 'employee',
        contributionBase: 4800,
      ),
    );
    expect(restore.processingStatus, 'completed');
    final restored = await insuranceRepository.findProfile(employee.id);
    expect(restored?.isInsured, isTrue);
    expect(restored?.contributionBase, 4800);
  });

  test('keeps pending type adjustment from changing current profile', () async {
    final employee = await createEmployee('EMP-I201', '王五');
    await insuranceRepository.saveProfile(
      draft: InsuranceProfileDraft(
        employeeId: employee.id,
        isInsured: true,
        insuranceType: 'employee',
        contributionBase: 4000,
        effectiveMonth: '2026-09',
      ),
    );
    await insuranceRepository.saveChange(
      draft: InsuranceChangeDraft(
        employeeId: employee.id,
        changeType: 'typeAdjustment',
        processingStatus: 'pending',
        effectiveMonth: '2026-10',
        insuranceType: 'resident',
      ),
    );
    expect(
      (await insuranceRepository.findProfile(employee.id))?.insuranceType,
      'employee',
    );
    final changes = await insuranceRepository
        .watchChanges(month: DateTime(2026, 10))
        .first;
    expect(changes.single.change.changeType, 'typeAdjustment');
    expect(InsuranceOptions.statusLabel('pending'), '待办理');
  });
}
