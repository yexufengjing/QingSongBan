import '../domain/assistant_models.dart';

/// Applies deterministic time and follow-up context after intent parsing.
class AssistantContextResolver {
  const AssistantContextResolver();

  ResolvedIntent resolveContext(
    AttendanceIntent intent,
    AssistantSessionContext session,
    AssistantPageContext? page,
    DateTime now,
  ) {
    final previous =
        session.lastBusinessType == AssistantBusinessType.attendance
        ? session.lastQuery
        : null;
    final previousVehicle = session.lastVehicleQuery?.vehicle;
    final previousMonth = previous?.yearMonth;
    final pageMonth = _validMonth(page?.yearMonth) ? page!.yearMonth : null;
    final businessType = intent.allVehicles
        ? AssistantBusinessType.vehicleAnnualRanking
        : _businessType(intent, session.lastBusinessType);
    final previousBusiness = session.lastBusinessType == businessType
        ? session.lastBusinessQuery
        : null;
    final relatedPersonContext =
        _isPersonBusinessType(businessType) &&
        _isPersonBusinessType(session.lastBusinessType);
    final priorPersonBusiness = relatedPersonContext &&
            session.lastBusinessType != AssistantBusinessType.attendance
        ? session.lastBusinessQuery
        : null;
    final contextMonth =
        previousBusiness?.yearMonth ??
        priorPersonBusiness?.yearMonth ??
        previousMonth;
    final businessOperation = intent.businessOperation == 'inherit'
        ? previousBusiness?.operation ?? 'summary'
        : intent.businessOperation;
    final inheritedBusinessSubject =
        previousBusiness?.subject ?? priorPersonBusiness?.subject;
    final resolvedBusinessSubject =
        intent.businessSubject ??
        (intent.businessOperation == 'inherit'
            ? inheritedBusinessSubject
            : null);

    String? yearMonth;
    var source = AssistantFieldSource.none;
    final month =
        intent.month ?? _monthOf(contextMonth) ?? _monthOf(pageMonth);
    final explicitYear = intent.yearReference == YearReference.explicit
        ? intent.year
        : null;

    if (intent.yearReference == YearReference.explicit &&
        (explicitYear == null || explicitYear < 1 || explicitYear > 9999)) {
      return _invalid(intent, businessType);
    }
    if (intent.yearReference != YearReference.explicit && intent.year != null) {
      return _invalid(intent, businessType);
    }
    if (month != null && (month < 1 || month > 12)) {
      return _invalid(intent, businessType);
    }

    final attendanceYear = switch (intent.yearReference) {
      YearReference.explicit => explicitYear,
      YearReference.current => now.year,
      YearReference.previous => now.year - 1,
      YearReference.inherit =>
        _yearOf(contextMonth) ?? _yearOf(pageMonth) ?? now.year,
      YearReference.unspecified =>
        _yearOf(contextMonth) ?? _yearOf(pageMonth) ?? now.year,
    };
    if (businessType != AssistantBusinessType.attendance &&
        businessType != AssistantBusinessType.vehicleExpenseAnalysis &&
        !_isBusinessQueryDomain(businessType) &&
        intent.month != null) {
      return _invalid(intent, businessType);
    }
    final inheritedVehicleYear = switch (session.lastBusinessType) {
      AssistantBusinessType.vehicleAnnualRepair =>
        session.lastVehicleQuery?.year,
      AssistantBusinessType.vehicleAnnualRanking =>
        session.lastRankingQuery?.year,
      AssistantBusinessType.attendance => null,
      AssistantBusinessType.vehicleExpenseAnalysis => null,
      AssistantBusinessType.personnel ||
      AssistantBusinessType.payroll ||
      AssistantBusinessType.inventory ||
      AssistantBusinessType.purchase ||
      AssistantBusinessType.distribution ||
      AssistantBusinessType.vehicleMaintenance ||
      AssistantBusinessType.vehicleReminders ||
      AssistantBusinessType.gardenRepair => null,
    };
    final pageVehicleYear =
        page?.year != null && page!.year! >= 1 && page.year! <= 9999
        ? page.year
        : null;
    final year = businessType == AssistantBusinessType.attendance
        ? attendanceYear
        : switch (intent.yearReference) {
            YearReference.explicit => explicitYear,
            YearReference.current => now.year,
            YearReference.previous => now.year - 1,
            YearReference.inherit || YearReference.unspecified =>
              (_isBusinessQueryDomain(businessType)
                      ? _yearOf(contextMonth)
                      : inheritedVehicleYear) ??
                  pageVehicleYear ??
                  now.year,
          };
    if (month != null && year != null) {
      yearMonth =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
      source = switch (intent.yearReference) {
        YearReference.explicit ||
        YearReference.current ||
        YearReference.previous => AssistantFieldSource.input,
        YearReference.inherit when contextMonth != null =>
          AssistantFieldSource.turn,
        YearReference.unspecified when contextMonth != null =>
          AssistantFieldSource.turn,
        _ when pageMonth != null => AssistantFieldSource.page,
        _ => AssistantFieldSource.currentYear,
      };
    } else if (_validMonth(contextMonth)) {
      yearMonth = contextMonth;
      source = AssistantFieldSource.turn;
    } else if (_validMonth(pageMonth)) {
      yearMonth = pageMonth;
      source = AssistantFieldSource.page;
    }

    final employeeText = businessType == AssistantBusinessType.attendance
        ? _nonEmpty(intent.employeeText) ?? priorPersonBusiness?.subject
        : null;
    final inheritedEmployee = employeeText == null ? previous?.employee : null;
    final employeeId = employeeText != null
        ? null
        : inheritedEmployee?.employeeId ?? page?.employeeId;
    final groupId = employeeText != null
        ? null
        : inheritedEmployee == null
        ? page?.groupId
        : previous?.groupId;
    final allVehicles =
        intent.allVehicles || intent.action == AttendanceAction.allVehicles;
    final vehicleText = allVehicles ? null : _nonEmpty(intent.vehicleText);
    final vehicleId = businessType == AssistantBusinessType.vehicleAnnualRepair
        ? vehicleText != null
              ? null
              : (session.lastBusinessType == businessType
                        ? previousVehicle?.vehicleId
                        : null) ??
                    page?.vehicleId
        : businessType == AssistantBusinessType.vehicleExpenseAnalysis
        ? vehicleText != null
              ? null
              : (session.lastBusinessType == businessType
                        ? session.lastVehicleExpenseVehicle?.vehicleId
                        : null) ??
                    page?.vehicleId
        : businessType == AssistantBusinessType.vehicleMaintenance ||
              businessType == AssistantBusinessType.vehicleReminders
        ? resolvedBusinessSubject == null ? page?.vehicleId : null
        : null;

    return ResolvedIntent(
      action: intent.action,
      yearMonth: businessType == AssistantBusinessType.attendance || _isBusinessQueryDomain(businessType)
          ? yearMonth
          : null,
      yearMonthSource: businessType == AssistantBusinessType.attendance || _isBusinessQueryDomain(businessType)
          ? source
          : AssistantFieldSource.none,
      requestedYear: year,
      employeeText: employeeText,
      employeeId: businessType == AssistantBusinessType.attendance ||
              businessType == AssistantBusinessType.personnel ||
              businessType == AssistantBusinessType.payroll
          ? resolvedBusinessSubject == null ? employeeId : null
          : null,
      groupId: businessType == AssistantBusinessType.attendance
          ? groupId
          : null,
      clarification: intent.clarification,
      businessType: businessType,
      vehicleText: vehicleText,
      vehicleId: vehicleId,
      allVehicles: allVehicles,
      expenseCategory: intent.expenseCategory,
      expensePeriod: intent.expensePeriod,
      expenseYearMonth:
          businessType == AssistantBusinessType.vehicleExpenseAnalysis
          ? intent.expenseYearMonth
          : null,
      businessQuestion: intent.businessQuestion,
      businessOperation: businessOperation,
      businessSubject: resolvedBusinessSubject,
    );
  }

  AssistantBusinessType _businessType(
    AttendanceIntent intent,
    AssistantBusinessType lastBusinessType,
  ) => switch (intent.action) {
    AttendanceAction.queryAttendance ||
    AttendanceAction.changeEmployee => AssistantBusinessType.attendance,
    AttendanceAction.queryVehicleAnnualRepair =>
      AssistantBusinessType.vehicleAnnualRepair,
    AttendanceAction.queryVehicleExpenseAnalysis =>
      AssistantBusinessType.vehicleExpenseAnalysis,
    AttendanceAction.queryVehicleAnnualRanking ||
    AttendanceAction.allVehicles => AssistantBusinessType.vehicleAnnualRanking,
    AttendanceAction.queryBusiness => intent.businessType,
    AttendanceAction.changeVehicle =>
      lastBusinessType == AssistantBusinessType.vehicleAnnualRanking
          ? AssistantBusinessType.vehicleAnnualRepair
          : lastBusinessType,
    AttendanceAction.changeYear ||
    AttendanceAction.refresh ||
    AttendanceAction.nextRankingPage ||
    AttendanceAction.clarify => lastBusinessType,
    AttendanceAction.unsupported => AssistantBusinessType.attendance,
  };

  bool _isBusinessQueryDomain(AssistantBusinessType type) => switch (type) {
    AssistantBusinessType.personnel ||
    AssistantBusinessType.payroll ||
    AssistantBusinessType.inventory ||
    AssistantBusinessType.purchase ||
    AssistantBusinessType.distribution ||
    AssistantBusinessType.vehicleMaintenance ||
    AssistantBusinessType.vehicleReminders ||
    AssistantBusinessType.gardenRepair => true,
    _ => false,
  };

  bool _isPersonBusinessType(AssistantBusinessType type) => switch (type) {
    AssistantBusinessType.attendance ||
    AssistantBusinessType.personnel ||
    AssistantBusinessType.payroll => true,
    _ => false,
  };

  static ResolvedIntent _invalid(
    AttendanceIntent intent,
    AssistantBusinessType businessType,
  ) => ResolvedIntent(
    action: intent.action,
    yearMonth: null,
    yearMonthSource: AssistantFieldSource.none,
    requestedYear: null,
    employeeText: intent.employeeText,
    error: AssistantErrorCode.invalidArgument,
    businessType: businessType,
  );

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static int? _yearOf(String? value) =>
      _validMonth(value) ? int.parse(value!.substring(0, 4)) : null;

  static int? _monthOf(String? value) =>
      _validMonth(value) ? int.parse(value!.substring(5, 7)) : null;

  static bool _validMonth(String? value) {
    if (value == null || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
      return false;
    }
    final year = int.parse(value.substring(0, 4));
    return year >= 1 && year <= 9999;
  }
}
