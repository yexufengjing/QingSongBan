abstract final class AppDateUtils {
  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String yearMonth(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }

  static String formatDate(DateTime? value) {
    if (value == null) {
      return '未填写';
    }
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static int ageAt(DateTime birthDate, {DateTime? onDate}) {
    final date = onDate ?? DateTime.now();
    var age = date.year - birthDate.year;
    if (date.month < birthDate.month ||
        (date.month == birthDate.month && date.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  static DateTime parseYearMonth(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid year-month: $value');
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final parsed = DateTime(year, month);
    if (parsed.year != year || parsed.month != month) {
      throw FormatException('Invalid year-month: $value');
    }
    return parsed;
  }
}
