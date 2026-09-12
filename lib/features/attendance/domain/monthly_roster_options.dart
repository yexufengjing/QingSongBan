import '../../../core/database/app_database.dart';

class MonthlyRosterEntryView {
  const MonthlyRosterEntryView({required this.roster, required this.employee});

  final MonthlyAttendanceRoster roster;
  final Employee employee;
}

class MonthlyRosterCounts {
  const MonthlyRosterCounts({this.activeCount = 0, this.removedCount = 0});

  final int activeCount;
  final int removedCount;
}

class MonthlyRosterCopyResult {
  const MonthlyRosterCopyResult({
    required this.sourceYearMonth,
    required this.count,
  });

  final String sourceYearMonth;
  final int count;
}
