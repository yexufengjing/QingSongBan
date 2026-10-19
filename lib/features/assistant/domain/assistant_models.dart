/// Shared contracts for the first, read-only assistant flow.
///
/// Business identity and attendance details stay in local types. Provider
/// requests use [IntentRequest] and [AttendanceOutboundSummary] only.
library;

enum AttendanceAction {
  queryAttendance,
  queryVehicleAnnualRepair,
  queryVehicleAnnualRanking,
  queryVehicleExpenseAnalysis,
  queryBusiness,
  changeYear,
  changeEmployee,
  changeVehicle,
  allVehicles,
  nextRankingPage,
  refresh,
  clarify,
  unsupported,
}

enum AssistantBusinessType {
  attendance,
  vehicleAnnualRepair,
  vehicleAnnualRanking,
  vehicleExpenseAnalysis,
  personnel,
  payroll,
  inventory,
  purchase,
  distribution,
  vehicleMaintenance,
  vehicleReminders,
  gardenRepair,
}

enum VehicleExpenseCategoryScope { all, repair, maintenance, fuel, manual }

enum VehicleExpenseGranularity { daily, monthly }

enum VehicleExpenseCoverage { complete, partial, unknown }

enum VehicleExpenseWorkloadMetric { mileage, workHours, workDays }

enum AssistantAgentPeriod {
  recent30Days,
  previous30Days,
  previousMonth,
  recent90Days,
}

enum AssistantAgentToolName {
  summarizeVehicleExpenses,
  compareVehicleExpensePeriods,
  inspectVehicleExpenseDrivers,
  comparePeerVehicleExpenses,
}

class AssistantAgentToolCall {
  const AssistantAgentToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final AssistantAgentToolName name;
  final Map<String, Object?> arguments;
}

class AssistantAgentMessage {
  const AssistantAgentMessage({
    required this.role,
    this.content,
    this.toolCalls = const [],
    this.toolCallId,
  });

  final String role;
  final String? content;
  final List<AssistantAgentToolCall> toolCalls;
  final String? toolCallId;
}

class AssistantAgentTurn {
  const AssistantAgentTurn({this.text, this.toolCalls = const []});

  final String? text;
  final List<AssistantAgentToolCall> toolCalls;
}

class AssistantAgentRunResult {
  const AssistantAgentRunResult({
    required this.periods,
    required this.evidence,
    required this.toolCalls,
    this.summaryText,
    this.stopped = false,
    this.failure,
    this.peerComparisons = const [],
    this.executedTools = const [],
  });

  final List<VehicleExpensePeriodResult> periods;
  final List<VehicleExpenseEvidence> evidence;
  final int toolCalls;
  final String? summaryText;
  final bool stopped;
  final AssistantErrorCode? failure;
  final List<VehicleExpensePeerResult> peerComparisons;
  final List<AssistantAgentToolName> executedTools;
}

class VehicleExpenseToolRequest {
  const VehicleExpenseToolRequest({
    required this.vehicleId,
    required this.period,
    this.scope = VehicleExpenseCategoryScope.all,
    this.comparisonPeriod,
    this.yearMonth,
  });

  /// Bound from a local, immutable page/session snapshot. Never model supplied.
  final int vehicleId;
  final AssistantAgentPeriod period;
  final VehicleExpenseCategoryScope scope;
  final AssistantAgentPeriod? comparisonPeriod;
  final String? yearMonth;
}

class VehicleExpenseCategoryResult {
  const VehicleExpenseCategoryResult({
    required this.category,
    required this.amountCents,
    required this.recordCount,
    required this.coverage,
  });

  final VehicleExpenseCategoryScope category;
  final int amountCents;
  final int recordCount;
  final VehicleExpenseCoverage coverage;
}

class VehicleFuelMonthResult {
  const VehicleFuelMonthResult({
    required this.year,
    required this.month,
    required this.amountCents,
    required this.liters,
    required this.coverage,
    this.workDays,
    this.mileage,
    this.workHours,
  });

  final int year;
  final int month;
  final int amountCents;
  final double liters;
  final int? workDays;
  final double? mileage;
  final double? workHours;
  final VehicleExpenseCoverage coverage;
}

class VehicleExpenseWorkload {
  const VehicleExpenseWorkload({
    this.mileage,
    this.workDays,
    this.workHours,
    required this.coverage,
  });

  final double? mileage;
  final int? workDays;
  final double? workHours;
  final VehicleExpenseCoverage coverage;
}

class VehicleExpensePeriodResult {
  const VehicleExpensePeriodResult({
    required this.startInclusive,
    required this.endExclusive,
    required this.granularity,
    required this.coverage,
    required this.categories,
    this.fuelMonths = const [],
    this.workload,
    this.coverageNotes = const [],
  });

  final DateTime startInclusive;
  final DateTime endExclusive;
  final VehicleExpenseGranularity granularity;
  final VehicleExpenseCoverage coverage;
  final List<VehicleExpenseCategoryResult> categories;
  final List<VehicleFuelMonthResult> fuelMonths;
  final VehicleExpenseWorkload? workload;
  final List<String> coverageNotes;
}

class VehicleExpenseEvidence {
  const VehicleExpenseEvidence({
    required this.label,
    this.amountCents,
    this.recordCount,
    this.previousAmountCents,
    this.deltaCents,
    this.contributionBasis,
    this.contributionPercent,
  });

  final String label;
  final int? amountCents;
  final int? recordCount;
  final int? previousAmountCents;
  final int? deltaCents;
  final String? contributionBasis;
  final double? contributionPercent;
}

class VehicleExpenseAnalysisAnswer {
  const VehicleExpenseAnalysisAnswer({
    required this.vehicleId,
    required this.vehicleLabel,
    required this.resultRef,
    required this.summaryText,
    required this.periods,
    required this.evidence,
    required this.sourceRule,
    required this.sourcePage,
    this.peerComparisons = const [],
    this.executedTools = const [],
    this.failure,
    this.stopped = false,
  });

  /// Local navigation only; excluded from all provider projections.
  final int vehicleId;
  final String vehicleLabel;
  final String resultRef;
  final String summaryText;
  final List<VehicleExpensePeriodResult> periods;
  final List<VehicleExpenseEvidence> evidence;
  final String sourceRule;
  final String sourcePage;
  final List<VehicleExpensePeerResult> peerComparisons;
  final List<AssistantAgentToolName> executedTools;
  final AssistantErrorCode? failure;
  final bool stopped;
}

enum YearReference { explicit, current, previous, inherit, unspecified }

enum AssistantFieldSource { input, turn, page, currentYear, none }

enum EmployeeResolutionStatus { unique, candidates, notFound, unavailable }

enum AttendanceReadStatus {
  success,
  notInRoster,
  selectionRequired,
  dataConflict,
  employeeUnavailable,
  failure,
}

enum AssistantErrorCode {
  missingContext,
  invalidArgument,
  entityNotFound,
  entityUnavailable,
  selectionRequired,
  notInRoster,
  dataConflict,
  noAttendanceRegistered,
  providerUnavailable,
  missingApiKey,
  network,
  timeout,
  unauthorized,
  rateLimited,
  invalidProviderResponse,
  staleResult,
  unsupported,
  cancelled,
  unknown,
}

enum AssistantTurnPhase { idle, parsing, resolving, reading, explaining }

enum AssistantResolutionPath { localFollowUp, modelParsed }

class AssistantProviderException implements Exception {
  const AssistantProviderException(this.code);

  final AssistantErrorCode code;
}

enum AttendanceCompleteness { notEvaluated, partial, complete }

class RequestToken {
  RequestToken([int? id]) : id = id ?? _allocateId();

  static var _nextId = 0;

  static int _allocateId() => _nextId++;

  final int id;
  bool _cancelled = false;
  var _nextCancellerId = 0;
  final Map<int, void Function()> _cancellers = {};
  bool get isCancelled => _cancelled;

  /// Register a transport abort callback and return a detach function.
  void Function() addCancelHandler(void Function() handler) {
    if (_cancelled) {
      handler();
      return () {};
    }
    final id = _nextCancellerId++;
    _cancellers[id] = handler;
    return () => _cancellers.remove(id);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final handlers = _cancellers.values.toList();
    _cancellers.clear();
    for (final handler in handlers) {
      handler();
    }
  }
}

class AssistantPageContext {
  const AssistantPageContext({
    required this.module,
    required this.page,
    this.yearMonth,
    this.groupId,
    this.employeeId,
    this.vehicleId,
    this.year,
  });

  final String module;
  final String page;
  final String? yearMonth;
  final int? groupId;
  final int? employeeId;
  final int? vehicleId;
  final int? year;
}

class IntentRequest {
  const IntentRequest({
    required this.text,
    required this.now,
    this.previousAction,
    this.previousYearMonth,
    this.hasPageEmployee = false,
    this.pageYearMonth,
    this.previousBusinessType = AssistantBusinessType.attendance,
    this.previousYear,
    this.hasPageVehicle = false,
    this.pageVehicleYear,
    this.previousExpenseCategory,
    this.previousExpensePeriod,
    this.previousExpenseYearMonth,
    this.previousBusinessQuestion,
    this.previousBusinessOperation,
    this.previousBusinessYearMonth,
  });

  final String text;
  final DateTime now;
  final AttendanceAction? previousAction;
  final String? previousYearMonth;
  final bool hasPageEmployee;
  final String? pageYearMonth;
  final AssistantBusinessType previousBusinessType;
  final int? previousYear;
  final bool hasPageVehicle;
  final int? pageVehicleYear;
  final VehicleExpenseCategoryScope? previousExpenseCategory;
  final AssistantAgentPeriod? previousExpensePeriod;
  final String? previousExpenseYearMonth;
  final String? previousBusinessQuestion;
  final String? previousBusinessOperation;
  final String? previousBusinessYearMonth;
}

class AttendanceIntent {
  const AttendanceIntent({
    required this.action,
    this.employeeText,
    this.year,
    this.yearReference = YearReference.unspecified,
    this.month,
    this.clarification,
    this.vehicleText,
    this.allVehicles = false,
    this.expenseCategory = VehicleExpenseCategoryScope.all,
    this.expensePeriod = AssistantAgentPeriod.recent30Days,
    this.expenseYearMonth,
    this.businessQuestion,
    this.businessType = AssistantBusinessType.attendance,
    this.businessSubject,
    this.businessOperation = 'summary',
  });

  final AttendanceAction action;
  final String? employeeText;
  final int? year;
  final YearReference yearReference;
  final int? month;
  final String? clarification;
  final String? vehicleText;
  final bool allVehicles;
  final VehicleExpenseCategoryScope expenseCategory;
  final AssistantAgentPeriod expensePeriod;
  final String? expenseYearMonth;
  final String? businessQuestion;
  final AssistantBusinessType businessType;
  final String? businessSubject;
  final String businessOperation;
}

class AssistantSessionContext {
  const AssistantSessionContext({
    this.lastQuery,
    this.pendingQuery,
    this.pendingEmployeeQuery,
    this.selectedCandidateRefs = const {},
    this.lastBusinessType = AssistantBusinessType.attendance,
    this.lastVehicleQuery,
    this.lastRankingQuery,
    this.lastVehicleExpenseVehicle,
    this.lastVehicleExpenseQuery,
    this.lastBusinessQuestion,
    this.lastBusinessQuery,
  });

  final ResolvedAttendanceQuery? lastQuery;
  final ResolvedAttendanceQuery? pendingQuery;
  final String? pendingEmployeeQuery;
  final Map<String, ResolvedEmployee> selectedCandidateRefs;
  final AssistantBusinessType lastBusinessType;
  final ResolvedVehicleAnnualRepairQuery? lastVehicleQuery;
  final ResolvedVehicleRankingQuery? lastRankingQuery;
  final ResolvedVehicle? lastVehicleExpenseVehicle;
  final ResolvedVehicleExpenseQuery? lastVehicleExpenseQuery;
  final String? lastBusinessQuestion;
  final AssistantBusinessQuery? lastBusinessQuery;
}

class ResolvedIntent {
  const ResolvedIntent({
    required this.action,
    required this.yearMonth,
    required this.yearMonthSource,
    this.requestedYear,
    this.employeeText,
    this.employeeId,
    this.groupId,
    this.clarification,
    this.error,
    this.businessType = AssistantBusinessType.attendance,
    this.vehicleText,
    this.vehicleId,
    this.allVehicles = false,
    this.expenseCategory = VehicleExpenseCategoryScope.all,
    this.expensePeriod = AssistantAgentPeriod.recent30Days,
    this.expenseYearMonth,
    this.businessQuestion,
    this.businessOperation = 'summary',
    this.businessSubject,
  });

  final AttendanceAction action;
  final String? yearMonth;
  final AssistantFieldSource yearMonthSource;
  final int? requestedYear;
  final String? employeeText;
  final int? employeeId;
  final int? groupId;
  final String? clarification;
  final AssistantErrorCode? error;
  final AssistantBusinessType businessType;
  final String? vehicleText;

  /// A locally resolved page-context vehicle ID; never model supplied.
  final int? vehicleId;
  final bool allVehicles;
  final VehicleExpenseCategoryScope expenseCategory;
  final AssistantAgentPeriod expensePeriod;
  final String? expenseYearMonth;
  final String? businessQuestion;
  final String businessOperation;
  final String? businessSubject;
}

class VehicleSelector {
  const VehicleSelector({
    this.vehicleText,
    this.vehicleId,
    this.existingVehicle,
  });

  final String? vehicleText;
  final int? vehicleId;
  final ResolvedVehicle? existingVehicle;
}

enum VehicleResolutionStatus { unique, candidates, notFound, unavailable }

class VehicleCandidate {
  const VehicleCandidate({
    required this.candidateRef,
    required this.vehicleId,
    required this.label,
    required this.vehicleNumber,
  });

  final String candidateRef;
  final int vehicleId;
  final String label;
  final String vehicleNumber;
}

class ResolvedVehicle {
  const ResolvedVehicle({
    required this.vehicleId,
    required this.label,
    required this.vehicleNumber,
  });

  final int vehicleId;
  final String label;
  final String vehicleNumber;

  int get id => vehicleId;
}

class VehicleResolution {
  const VehicleResolution({
    required this.status,
    this.vehicle,
    this.candidates = const [],
    this.error,
  });

  final VehicleResolutionStatus status;
  final ResolvedVehicle? vehicle;
  final List<VehicleCandidate> candidates;
  final AssistantErrorCode? error;
}

class ResolvedVehicleAnnualRepairQuery {
  const ResolvedVehicleAnnualRepairQuery({
    required this.vehicle,
    required this.year,
  });

  final ResolvedVehicle vehicle;
  final int year;
}

class ResolvedVehicleExpenseQuery {
  const ResolvedVehicleExpenseQuery({
    required this.vehicle,
    required this.period,
    required this.scope,
    this.yearMonth,
  });

  final ResolvedVehicle vehicle;
  final AssistantAgentPeriod period;
  final VehicleExpenseCategoryScope scope;
  final String? yearMonth;
}

class VehicleRepairLocalDetail {
  const VehicleRepairLocalDetail({
    required this.repairOrderId,
    required this.reportDate,
    required this.completedAt,
    required this.actualAmountCents,
  });

  final int repairOrderId;
  final DateTime reportDate;
  final DateTime? completedAt;
  final int actualAmountCents;
}

enum VehicleAnnualRepairReadStatus { success, empty, unavailable, failure }

class VehicleAnnualRepairResult {
  const VehicleAnnualRepairResult({
    required this.status,
    required this.vehicle,
    required this.year,
    required this.queriedAt,
    required this.completedRepairCount,
    required this.actualAmountCents,
    this.resultRef,
    this.details = const [],
    this.error,
    this.sourceRule = 'vehicle_repair_completed_report_year_v1',
  });

  final VehicleAnnualRepairReadStatus status;
  final ResolvedVehicle vehicle;
  final int year;
  final DateTime queriedAt;
  final int completedRepairCount;
  final int actualAmountCents;
  final String? resultRef;
  final List<VehicleRepairLocalDetail> details;
  final AssistantErrorCode? error;
  final String sourceRule;
  String get currency => 'CNY';
}

class ResolvedVehicleRankingQuery {
  const ResolvedVehicleRankingQuery({
    required this.year,
    this.limit = 10,
    this.resultRef,
    this.cursor,
  });

  final int year;
  final int limit;
  final String? resultRef;
  final String? cursor;
}

class VehicleRankingRow {
  const VehicleRankingRow({
    required this.vehicleId,
    required this.vehicleLabel,
    required this.vehicleNumber,
    required this.rank,
    required this.completedRepairCount,
    required this.actualAmountCents,
    required this.alias,
  });

  final int vehicleId;
  final String vehicleLabel;
  final String vehicleNumber;
  final int rank;
  final int completedRepairCount;
  final int actualAmountCents;
  final String alias;
}

class VehicleRankingPage {
  const VehicleRankingPage({
    required this.resultRef,
    required this.year,
    required this.queriedAt,
    required this.rows,
    required this.totalVehicleCount,
    required this.returnedCount,
    required this.hasMore,
    this.hasRepairRecords = false,
    this.nextCursor,
    this.error,
    this.sourceRule = 'vehicle_repair_completed_report_year_v1',
  });

  final String resultRef;
  final int year;
  final DateTime queriedAt;
  final List<VehicleRankingRow> rows;
  final int totalVehicleCount;
  final int returnedCount;
  final bool hasMore;
  final bool hasRepairRecords;
  final String? nextCursor;
  final AssistantErrorCode? error;
  final String sourceRule;
}

class EmployeeSelector {
  const EmployeeSelector({
    this.employeeText,
    this.employeeId,
    this.existingEmployee,
    required this.yearMonth,
    this.groupId,
  });

  final String? employeeText;
  final int? employeeId;
  final ResolvedEmployee? existingEmployee;
  final String yearMonth;
  final int? groupId;
}

class EmployeeCandidate {
  const EmployeeCandidate({
    required this.candidateRef,
    required this.employeeId,
    required this.label,
    this.employeeNumber,
    this.groupLabel,
  });

  final String candidateRef;
  final int employeeId;
  final String label;
  final String? employeeNumber;
  final String? groupLabel;
}

class ResolvedEmployee {
  const ResolvedEmployee({
    required this.employeeId,
    required this.label,
    this.employeeNumber,
  });

  final int employeeId;
  final String label;
  final String? employeeNumber;
}

class EmployeeResolution {
  const EmployeeResolution({
    required this.status,
    this.employee,
    this.candidates = const [],
    this.error,
  });

  final EmployeeResolutionStatus status;
  final ResolvedEmployee? employee;
  final List<EmployeeCandidate> candidates;
  final AssistantErrorCode? error;
}

class ResolvedAttendanceQuery {
  const ResolvedAttendanceQuery({
    required this.employee,
    required this.yearMonth,
    required this.yearMonthSource,
    this.groupId,
  });

  final ResolvedEmployee employee;
  final String yearMonth;
  final AssistantFieldSource yearMonthSource;
  final int? groupId;
}

class AttendanceDayDetail {
  const AttendanceDayDetail({
    required this.date,
    required this.morningStatus,
    required this.afternoonStatus,
  });

  final DateTime date;
  final String morningStatus;
  final String afternoonStatus;
}

class OvertimeDetail {
  const OvertimeDetail({required this.date, required this.durationMinutes});

  final DateTime date;
  final int durationMinutes;
}

class AttendanceLocalDetails {
  const AttendanceLocalDetails({
    required this.attendanceDaysByDate,
    required this.overtime,
  });

  final List<AttendanceDayDetail> attendanceDaysByDate;
  final List<OvertimeDetail> overtime;
}

class AttendanceReadResult {
  const AttendanceReadResult({
    required this.status,
    required this.employeeLabel,
    required this.yearMonth,
    required this.queriedAt,
    required this.completeness,
    this.groupLabels = const [],
    this.groupIds = const [],
    this.attendanceDays,
    this.leaveAndRestDays,
    this.overtimeMinutes,
    this.details,
    this.sourceRule = 'monthly-attendance-table-v1',
    this.sourcePage = '/attendance/monthly-table',
    this.error,
  });

  final AttendanceReadStatus status;
  final String employeeLabel;
  final String yearMonth;
  final DateTime queriedAt;
  final AttendanceCompleteness completeness;
  final List<String> groupLabels;
  final List<int> groupIds;
  final double? attendanceDays;
  final double? leaveAndRestDays;
  final int? overtimeMinutes;
  final AttendanceLocalDetails? details;
  final String sourceRule;
  final String sourcePage;
  final AssistantErrorCode? error;
}

/// A deliberate allowlist projection. It cannot contain identity or details.
class AttendanceOutboundSummary {
  const AttendanceOutboundSummary({
    required this.yearMonth,
    required this.attendanceDays,
    required this.leaveAndRestDays,
    required this.overtimeMinutes,
  });

  final String yearMonth;
  final double attendanceDays;
  final double leaveAndRestDays;
  final int overtimeMinutes;

  Map<String, Object> toJson() => {
    'yearMonth': yearMonth,
    'attendanceDays': attendanceDays,
    'leaveAndRestDays': leaveAndRestDays,
    'overtimeMinutes': overtimeMinutes,
  };
}

class VehicleAnnualRepairOutboundSummary {
  const VehicleAnnualRepairOutboundSummary({
    required this.year,
    required this.completedRepairCount,
    required this.actualAmountCents,
    this.currency = 'CNY',
  });

  final int year;
  final int completedRepairCount;
  final int actualAmountCents;
  final String currency;
}

class VehicleRankingOutboundProjection {
  const VehicleRankingOutboundProjection({
    required this.year,
    required this.rows,
    required this.totalVehicleCount,
    required this.returnedCount,
    required this.hasMore,
    this.nextCursor,
  });

  final int year;
  final List<VehicleRankingOutboundRow> rows;
  final int totalVehicleCount;
  final int returnedCount;
  final bool hasMore;
  final String? nextCursor;
}

class VehicleRankingOutboundRow {
  const VehicleRankingOutboundRow({
    required this.alias,
    required this.rank,
    required this.completedRepairCount,
    required this.actualAmountCents,
  });

  final String alias;
  final int rank;
  final int completedRepairCount;
  final int actualAmountCents;
}

class SummaryExplanation {
  const SummaryExplanation({required this.text});

  final String text;
}

class ConnectionCheck {
  const ConnectionCheck({required this.success, this.error});

  final bool success;
  final AssistantErrorCode? error;
}

class AssistantTurnMetrics {
  const AssistantTurnMetrics({
    required this.resolutionPath,
    this.parseCalls = 0,
    this.explanationCalls = 0,
    this.parseDuration,
    this.localReadDuration,
    this.elapsed,
    this.providerCalls,
    this.inputTokens,
    this.outputTokens,
    this.providerDuration,
  });

  final AssistantResolutionPath resolutionPath;
  final int parseCalls;
  final int explanationCalls;
  final Duration? parseDuration;
  final Duration? localReadDuration;
  final Duration? elapsed;
  final int? providerCalls;
  final int? inputTokens;
  final int? outputTokens;
  final Duration? providerDuration;
}

class AIProviderUsageSnapshot {
  const AIProviderUsageSnapshot({
    required this.parseCalls,
    required this.explanationCalls,
    required this.connectionChecks,
    this.agentCalls = 0,
    this.inputTokens,
    this.outputTokens,
    required this.totalDuration,
  });

  final int parseCalls;
  final int explanationCalls;
  final int connectionChecks;
  final int agentCalls;
  final int? inputTokens;
  final int? outputTokens;
  final Duration totalDuration;

  int get requestCount =>
      parseCalls + explanationCalls + connectionChecks + agentCalls;
}

abstract interface class AIProviderUsage {
  AIProviderUsageSnapshot get usageSnapshot;

  AIProviderUsageSnapshot usageForRequest(int requestId);
}

class AssistantAnswer {
  const AssistantAnswer({
    required this.text,
    required this.employeeLabel,
    required this.yearMonth,
    required this.queriedAt,
    required this.completeness,
    required this.yearMonthSource,
    this.attendanceDays,
    this.leaveAndRestDays,
    this.overtimeMinutes,
    this.groupLabels = const [],
    this.groupIds = const [],
    this.localDetails,
    this.sourceRule,
    this.sourcePage,
    this.explanation,
    this.error,
    this.vehicleSummary,
    this.vehicleRanking,
    this.vehicleExpenseAnalysis,
    this.businessResult,
  });

  final String text;
  final String employeeLabel;
  final String yearMonth;
  final DateTime queriedAt;
  final AttendanceCompleteness completeness;
  final AssistantFieldSource yearMonthSource;
  final double? attendanceDays;
  final double? leaveAndRestDays;
  final int? overtimeMinutes;
  final List<String> groupLabels;
  final List<int> groupIds;
  final AttendanceLocalDetails? localDetails;
  final String? sourceRule;
  final String? sourcePage;
  final String? explanation;
  final AssistantErrorCode? error;
  final VehicleAnnualRepairResult? vehicleSummary;
  final VehicleRankingPage? vehicleRanking;
  final VehicleExpenseAnalysisAnswer? vehicleExpenseAnalysis;
  final AssistantBusinessReadResult? businessResult;
}

class AssistantBusinessQuery {
  const AssistantBusinessQuery({
    required this.domain,
    required this.question,
    this.now,
    this.yearMonth,
    this.subject,
    this.operation = 'summary',
    this.employeeId,
    this.vehicleId,
  });

  final AssistantBusinessType domain;
  final String question;
  final DateTime? now;
  final String? yearMonth;
  final String? subject;
  final String operation;
  final int? employeeId;
  final int? vehicleId;
}

class AssistantBusinessFact {
  const AssistantBusinessFact({
    required this.label,
    required this.value,
    this.explanation,
    this.sourcePage,
  });

  final String label;
  final String value;
  final String? explanation;
  final String? sourcePage;
}

class AssistantBusinessReadResult {
  const AssistantBusinessReadResult({
    required this.domain,
    required this.title,
    required this.summary,
    required this.queriedAt,
    required this.sourceRule,
    required this.sourcePage,
    this.facts = const [],
    this.relatedReads = const [],
    this.error,
  });

  final AssistantBusinessType domain;
  final String title;
  final String summary;
  final DateTime queriedAt;
  final String sourceRule;
  final String sourcePage;
  final List<AssistantBusinessFact> facts;
  final List<AssistantBusinessReadResult> relatedReads;
  final AssistantErrorCode? error;
}

class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.answer,
    this.candidates = const [],
    this.vehicleCandidates = const [],
    this.error,
    this.metrics,
    this.localQuery,
    this.vehicleQuery,
    this.expenseQuery,
    this.rankingQuery,
    this.businessQuery,
    this.resultRef,
  });

  final int id;
  final String text;
  final bool isUser;
  final AssistantAnswer? answer;
  final List<EmployeeCandidate> candidates;
  final List<VehicleCandidate> vehicleCandidates;
  final AssistantErrorCode? error;
  final AssistantTurnMetrics? metrics;
  final ResolvedAttendanceQuery? localQuery;
  final ResolvedVehicleAnnualRepairQuery? vehicleQuery;
  final ResolvedVehicleExpenseQuery? expenseQuery;
  final ResolvedVehicleRankingQuery? rankingQuery;
  final AssistantBusinessQuery? businessQuery;
  final String? resultRef;
}

class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.phase = AssistantTurnPhase.idle,
    this.session = const AssistantSessionContext(),
    this.pendingRequest,
    this.lastResolutionPath,
    this.agentProgress,
  });

  final List<AssistantMessage> messages;
  final AssistantTurnPhase phase;
  final AssistantSessionContext session;
  final RequestToken? pendingRequest;
  final AssistantResolutionPath? lastResolutionPath;
  final String? agentProgress;

  bool get isBusy => phase != AssistantTurnPhase.idle;
}

abstract interface class AIProvider {
  Future<AttendanceIntent> parseIntent(
    IntentRequest request,
    RequestToken token,
  );

  Future<SummaryExplanation> explainSummary(
    AttendanceOutboundSummary summary,
    RequestToken token,
  );

  Future<ConnectionCheck> checkConnection(RequestToken token);
}

abstract interface class VehicleExpenseAgentProvider {
  Future<AssistantAgentTurn> completeAgentTurn(
    List<AssistantAgentMessage> messages,
    RequestToken token,
  );
}

abstract interface class VehicleExpenseReadPort {
  Future<VehicleExpensePeriodResult> readVehicleExpenses(
    VehicleExpenseToolRequest request,
  );

  Future<VehicleExpensePeerResult> comparePeerVehicleExpenses(
    VehicleExpenseToolRequest request,
  );
}

class VehicleExpensePeerResult {
  const VehicleExpensePeerResult({
    required this.period,
    required this.category,
    required this.comparableVehicleCount,
    required this.peerAmountCents,
    required this.targetAmountCents,
    required this.comparability,
    this.targetWorkload,
    this.peerWorkload,
    this.note,
    this.targetCentsPerKilometer,
    this.peerMeanCentsPerKilometer,
    this.metricUnit,
    this.targetUnitCost,
    this.peerUnitCost,
  });

  final VehicleExpensePeriodResult period;
  final VehicleExpenseCategoryScope category;
  final int comparableVehicleCount;
  final int? peerAmountCents;
  final int? targetAmountCents;
  final VehicleExpenseCoverage comparability;
  final VehicleExpenseWorkload? targetWorkload;
  final VehicleExpenseWorkload? peerWorkload;
  final String? note;
  final double? targetCentsPerKilometer;
  final double? peerMeanCentsPerKilometer;
  final VehicleExpenseWorkloadMetric? metricUnit;
  final double? targetUnitCost;
  final double? peerUnitCost;
}

abstract interface class AttendanceReadPort {
  Future<EmployeeResolution> resolveEmployee(EmployeeSelector selector);

  Future<EmployeeResolution> resolveCandidate(String candidateRef);

  Future<AttendanceReadResult> readMonth(ResolvedAttendanceQuery query);
}

abstract interface class VehicleReadPort {
  Future<VehicleResolution> resolveVehicle(VehicleSelector selector);

  Future<VehicleResolution> resolveVehicleCandidate(String candidateRef);

  Future<VehicleAnnualRepairResult> readVehicleAnnualRepairs(
    ResolvedVehicleAnnualRepairQuery query,
  );

  Future<VehicleRankingPage> readAnnualVehicleRanking(
    ResolvedVehicleRankingQuery query,
  );

  Future<VehicleRankingPage> readNextVehicleRankingPage({
    required String resultRef,
    required String cursor,
  });
}

abstract interface class AssistantBusinessReadPort {
  Future<AssistantBusinessReadResult> read(AssistantBusinessQuery query);
}

abstract interface class AssistantKeyStore {
  Future<bool> hasKey();

  Future<String?> readKey();

  Future<void> saveKey(String key);

  Future<void> removeKey();
}

abstract interface class AssistantActions {
  Future<void> submit(String utterance);

  Future<void> selectCandidate(String candidateRef);

  Future<void> refreshResult(String resultRef);

  Future<void> loadNextVehicleRankingPage(String resultRef, String cursor);

  Future<void> openRankedVehicle(String resultRef, int vehicleId);

  void updatePageContext(AssistantPageContext? context);

  void cancelCurrentTask();

  void clearSession();
}
