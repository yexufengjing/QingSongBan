import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/demo_data_seeder.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() async {
    await database.close();
  });

  test('seeds coherent Chinese demo data only once', () async {
    expect(await DemoDataSeeder.seed(database), isTrue);

    final employees = await database.listEmployees();
    final groups = await database.select(database.attendanceGroups).get();
    final rosters = await database
        .select(database.monthlyAttendanceRosters)
        .get();
    final attendance = await database.select(database.attendanceRecords).get();
    final leaves = await database.select(database.leaveRecords).get();
    final overtime = await database.select(database.overtimeRecords).get();
    final terminations = await database
        .select(database.terminationRecords)
        .get();
    final reminders = await database.select(database.reminders).get();
    final wageJobTypes = await database.select(database.wageJobTypes).get();
    final wageRates = await database.select(database.wageRateHistory).get();
    final wageProfiles = await database
        .select(database.employeeWageProfiles)
        .get();
    final payrollBatches = await database.select(database.payrollBatches).get();
    final payrollItems = await database.select(database.payrollItems).get();

    expect(employees, hasLength(10));
    expect(employees.map((employee) => employee.name), contains('张伟'));
    expect(employees.map((employee) => employee.name), contains('吴敏'));
    expect(
      groups.map((group) => group.name),
      containsAll(['生产一组', '行政支持组', '夜班组']),
    );
    expect(rosters, isNotEmpty);
    expect(attendance, isNotEmpty);
    expect(leaves, hasLength(3));
    expect(overtime, hasLength(1));
    expect(terminations, hasLength(1));
    expect(reminders, hasLength(3));
    expect(wageJobTypes, hasLength(7));
    expect(wageJobTypes.map((type) => type.name), contains('夜班保洁'));
    expect(wageJobTypes.where((type) => !type.isActive), hasLength(1));
    expect(wageRates, hasLength(14));
    expect(wageProfiles, hasLength(2));
    expect(payrollBatches, hasLength(2));
    expect(payrollItems, hasLength(4));

    expect(await DemoDataSeeder.seed(database), isFalse);
    expect(await database.listEmployees(), hasLength(10));
  });
}
