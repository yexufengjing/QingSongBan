// ignore_for_file: prefer_initializing_formals

import '../domain/assistant_models.dart';
import '../domain/assistant_quick_query.dart';
import 'assistant_answer_formatter.dart';
import 'assistant_context_resolver.dart';
import 'assistant_vehicle_expense_runner.dart';

typedef AssistantClock = DateTime Function();
typedef _ProviderUsageDelta = ({
  int? calls,
  int? inputTokens,
  int? outputTokens,
  Duration? duration,
});

/// In-memory conversation coordinator. UI/state management wraps this class.
class AssistantController implements AssistantActions {
  AssistantController({
    required AIProvider provider,
    required AttendanceReadPort attendance,
    VehicleReadPort? vehicles,
    VehicleExpenseReadPort? expenseReader,
    AssistantBusinessReadPort? businessReader,
    AssistantClock? clock,
    AssistantContextResolver resolver = const AssistantContextResolver(),
    AssistantAnswerFormatter formatter = const AssistantAnswerFormatter(),
  }) : _provider = provider,
       _attendance = attendance,
       _vehicles =
           vehicles ??
           (attendance is VehicleReadPort
               ? attendance as VehicleReadPort
               : null),
       _expenseReader =
           expenseReader ??
           (attendance is VehicleExpenseReadPort
               ? attendance as VehicleExpenseReadPort
               : null),
       _businessReader = businessReader,
       _clock = clock ?? DateTime.now,
       _resolver = resolver,
       _formatter = formatter;

  final AIProvider _provider;
  final AttendanceReadPort _attendance;
  final VehicleReadPort? _vehicles;
  final VehicleExpenseReadPort? _expenseReader;
  final AssistantBusinessReadPort? _businessReader;
  final AssistantClock _clock;
  final AssistantContextResolver _resolver;
  final AssistantAnswerFormatter _formatter;
  AssistantVehicleExpenseRunner? _expenseRunner;
  VehicleExpenseAnalysisAnswer? _activeExpensePartial;
  ResolvedVehicle? _activeExpenseVehicle;
  ResolvedVehicleExpenseQuery? _activeExpenseQuery;
  String? _activeExpenseText;
  String? _activeBusinessQuestion;

  AssistantState _state = const AssistantState();
  AssistantState get state => _state;
  void Function(AssistantState state)? onStateChanged;

  AssistantPageContext? _pageContext;
  int? _pendingPageVehicleSelection;
  ResolvedIntent? _pendingIntent;
  AssistantResolutionPath? _pendingResolutionPath;
  bool _awaitingEmployeeReply = false;
  var _nextMessageId = 0;
  String? _candidateInFlight;
  final Set<String> _pendingCandidateRefs = {};
  final Set<String> _pendingVehicleCandidateRefs = {};
  final Set<String> _invalidatedRankingRefs = {};

  @override
  Future<void> submit(String utterance) async {
    final text = utterance.trim();
    if (text.isEmpty || _state.isBusy) return;
    _activeExpenseText = text;
    _activeBusinessQuestion = text;
    final startedAt = _clock();
    final pageContext = _pageContext;
    final pageVehicleSelection = _pendingPageVehicleSelection;
    final turnSession = _sessionForPageVehicleSelection(
      _state.session,
      pageVehicleSelection,
      pageContext,
    );
    final userMessage = AssistantMessage(
      id: _nextMessageId++,
      text: text,
      isUser: true,
    );
    _emit(_copyState(messages: [..._state.messages, userMessage]));

    final pending = _pendingIntent;
    if (pending != null &&
        _awaitingEmployeeReply &&
        _isSingleEntityReply(text)) {
      _pendingIntent = null;
      _awaitingEmployeeReply = false;
      await _runResolvedIntent(
        pending.businessType == AssistantBusinessType.vehicleAnnualRepair
            ? pending.copyWith(vehicleText: text, clearVehicleId: true)
            : pending.copyWith(
                employeeText: text,
                employeeId: null,
                clearEmployeeId: true,
              ),
        path: _pendingResolutionPath ?? AssistantResolutionPath.localFollowUp,
        token: _newToken(),
        startedAt: startedAt,
      );
      return;
    }
    if (pending != null && !_awaitingEmployeeReply && _isMonthReply(text)) {
      _pendingIntent = null;
      _awaitingEmployeeReply = false;
      await _runResolvedIntent(
        pending.copyWith(
          yearMonth: _resolveMonthReply(text, pending.requestedYear),
        ),
        path: _pendingResolutionPath ?? AssistantResolutionPath.localFollowUp,
        token: _newToken(),
        startedAt: startedAt,
      );
      return;
    }

    _pendingIntent = null;
    _awaitingEmployeeReply = false;
    _pendingResolutionPath = null;
    _pendingCandidateRefs.clear();
    _pendingVehicleCandidateRefs.clear();

    final local = _parseExplicitLocalFollowUp(text, turnSession);
    if (local != null) {
      final resolved = _resolver.resolveContext(
        local,
        turnSession,
        pageContext,
        _clock(),
      );
      _consumePageVehicleSelection(pageVehicleSelection, resolved.action);
      await _runResolvedIntent(
        resolved,
        path: AssistantResolutionPath.localFollowUp,
        token: _newToken(),
        startedAt: startedAt,
      );
      return;
    }

    final token = _newToken();
    final parseStarted = _clock();
    _emit(_copyState(phase: AssistantTurnPhase.parsing));
    try {
      final session = turnSession;
      final previous =
          session.lastBusinessType == AssistantBusinessType.attendance
          ? session.lastQuery
          : null;
      final previousYear = switch (session.lastBusinessType) {
        AssistantBusinessType.attendance => int.tryParse(
          previous?.yearMonth.substring(0, 4) ?? '',
        ),
        AssistantBusinessType.vehicleAnnualRepair =>
          session.lastVehicleQuery?.year,
        AssistantBusinessType.vehicleAnnualRanking =>
          session.lastRankingQuery?.year,
        AssistantBusinessType.vehicleExpenseAnalysis ||
        AssistantBusinessType.personnel ||
        AssistantBusinessType.payroll ||
        AssistantBusinessType.inventory ||
        AssistantBusinessType.purchase ||
        AssistantBusinessType.distribution ||
        AssistantBusinessType.vehicleMaintenance ||
        AssistantBusinessType.vehicleReminders ||
        AssistantBusinessType.gardenRepair => null,
      };
      final intent = await _provider.parseIntent(
        IntentRequest(
          text: text,
          now: _clock(),
          previousAction: previous == null
              ? null
              : AttendanceAction.queryAttendance,
          previousYearMonth: previous?.yearMonth,
          hasPageEmployee: pageContext?.employeeId != null,
          pageYearMonth: pageContext?.yearMonth,
          previousBusinessType: session.lastBusinessType,
          previousYear: previousYear,
          hasPageVehicle: pageContext?.vehicleId != null,
          pageVehicleYear: pageContext?.year,
          previousExpenseCategory: session.lastVehicleExpenseQuery?.scope,
          previousExpensePeriod: session.lastVehicleExpenseQuery?.period,
          previousExpenseYearMonth: session.lastVehicleExpenseQuery?.yearMonth,
          previousBusinessQuestion: session.lastBusinessQuestion,
          previousBusinessOperation: session.lastBusinessQuery?.operation,
          previousBusinessYearMonth:
              session.lastBusinessQuery?.yearMonth,
        ),
        token,
      );
      if (!_isCurrent(token)) return;
      final parseDuration = _clock().difference(parseStarted);
      final resolved = _resolver.resolveContext(
        intent,
        session,
        pageContext,
        _clock(),
      );
      _consumePageVehicleSelection(pageVehicleSelection, resolved.action);
      await _runResolvedIntent(
        resolved,
        path: AssistantResolutionPath.modelParsed,
        token: token,
        startedAt: startedAt,
        parseCalls: 1,
        parseDuration: parseDuration,
      );
    } on AssistantProviderException catch (error) {
      if (!_isCurrent(token)) return;
      _appendError(
        error.code,
        _providerErrorText(error.code),
        AssistantResolutionPath.modelParsed,
        startedAt,
        parseCalls: 1,
        parseDuration: _clock().difference(parseStarted),
        token: token,
      );
    } catch (_) {
      if (!_isCurrent(token)) return;
      _appendError(
        AssistantErrorCode.providerUnavailable,
        '未能可靠理解这句话，请换种说法。',
        AssistantResolutionPath.modelParsed,
        startedAt,
        parseCalls: 1,
        parseDuration: _clock().difference(parseStarted),
        token: token,
      );
    }
  }

  /// Runs a saved shortcut through the same local readers as resolved intents.
  /// The scope is taken only from [query], never from chat or page context.
  Future<void> runQuickQuery(AssistantQuickQuery query) async {
    if (_state.isBusy) return;
    _clearPendingContexts();
    final startedAt = _clock();
    _emit(
      _copyState(
        messages: [
          ..._state.messages,
          AssistantMessage(
            id: _nextMessageId++,
            text: query.title,
            isUser: true,
          ),
        ],
      ),
    );
    final token = _newToken();
    final month =
        query.yearMonth ?? _formatMonth(startedAt.year, startedAt.month);
    if (_isMonthKind(query.kind) && !_validYearMonth(month)) {
      _appendError(
        AssistantErrorCode.invalidArgument,
        '月份无效，请重新选择。',
        AssistantResolutionPath.localFollowUp,
        startedAt,
        token: token,
      );
      return;
    }
    if ((query.kind == AssistantQuickQueryKind.attendance ||
            query.kind == AssistantQuickQueryKind.payroll) &&
        query.employeeId == null) {
      _appendPrompt(
        '请先选择一位人员。',
        AssistantResolutionPath.localFollowUp,
        startedAt,
        0,
        null,
        token,
      );
      return;
    }
    if (query.kind == AssistantQuickQueryKind.vehicleRepair &&
        query.vehicleId == null) {
      _appendPrompt(
        '请先选择一辆车。',
        AssistantResolutionPath.localFollowUp,
        startedAt,
        0,
        null,
        token,
      );
      return;
    }

    _activeBusinessQuestion = query.title;
    final intent = switch (query.kind) {
      AssistantQuickQueryKind.attendance => ResolvedIntent(
        action: AttendanceAction.queryAttendance,
        yearMonth: month,
        yearMonthSource: query.yearMonth == null
            ? AssistantFieldSource.currentYear
            : AssistantFieldSource.input,
        employeeId: query.employeeId,
        businessType: AssistantBusinessType.attendance,
      ),
      AssistantQuickQueryKind.payroll => ResolvedIntent(
        action: AttendanceAction.queryBusiness,
        yearMonth: month,
        yearMonthSource: query.yearMonth == null
            ? AssistantFieldSource.currentYear
            : AssistantFieldSource.input,
        employeeId: query.employeeId,
        businessType: AssistantBusinessType.payroll,
        businessQuestion: query.title,
        businessOperation: 'summary',
      ),
      AssistantQuickQueryKind.inventoryLowStock => ResolvedIntent(
        action: AttendanceAction.queryBusiness,
        yearMonth: null,
        yearMonthSource: AssistantFieldSource.none,
        businessType: AssistantBusinessType.inventory,
        businessQuestion: query.title,
        businessOperation: 'lowStock',
      ),
      AssistantQuickQueryKind.purchasePending => ResolvedIntent(
        action: AttendanceAction.queryBusiness,
        yearMonth: null,
        yearMonthSource: AssistantFieldSource.none,
        businessType: AssistantBusinessType.purchase,
        businessQuestion: query.title,
        businessOperation: 'pending',
      ),
      AssistantQuickQueryKind.distribution => ResolvedIntent(
        action: AttendanceAction.queryBusiness,
        yearMonth: month,
        yearMonthSource: query.yearMonth == null
            ? AssistantFieldSource.currentYear
            : AssistantFieldSource.input,
        businessType: AssistantBusinessType.distribution,
        businessQuestion: query.title,
        businessOperation: 'summary',
      ),
      AssistantQuickQueryKind.vehicleRepair => ResolvedIntent(
        action: AttendanceAction.queryBusiness,
        yearMonth: month,
        yearMonthSource: query.yearMonth == null
            ? AssistantFieldSource.currentYear
            : AssistantFieldSource.input,
        vehicleId: query.vehicleId,
        businessType: AssistantBusinessType.vehicleMaintenance,
        businessQuestion: query.title,
        businessOperation: 'summary',
      ),
    };
    await _runResolvedIntent(
      intent,
      path: AssistantResolutionPath.localFollowUp,
      token: token,
      startedAt: startedAt,
    );
  }

  /// Re-runs a query from the selected result message, retaining that result's
  /// subject and domain even when the conversation has moved on.
  Future<void> runFollowUp(
    int messageId, {
    String? yearMonth,
    String? operation,
  }) async {
    if (_state.isBusy || yearMonth != null && !_validYearMonth(yearMonth)) {
      return;
    }
    final message = _state.messages
        .where(
          (item) => item.id == messageId && !item.isUser && item.answer != null,
        )
        .firstOrNull;
    if (message == null) return;
    if (message.businessQuery case final original?) {
      if (!_supportsDeterministicBusinessFollowUp(original.domain)) return;
    }
    if (message.localQuery == null &&
        message.businessQuery == null &&
        message.vehicleQuery == null) {
      return;
    }
    _clearPendingContexts();
    final startedAt = _clock();
    final token = _newToken();
    if (message.localQuery case final original?) {
      final updated = ResolvedAttendanceQuery(
        employee: original.employee,
        yearMonth: yearMonth ?? original.yearMonth,
        yearMonthSource: yearMonth == null
            ? original.yearMonthSource
            : AssistantFieldSource.input,
        groupId: original.groupId,
      );
      await _readAndAnswer(
        updated,
        token,
        startedAt,
        path: AssistantResolutionPath.localFollowUp,
      );
      return;
    }
    if (message.businessQuery case final original?) {
      final domain = original.domain;
      final query = AssistantBusinessQuery(
        domain: domain,
        question: original.question,
        now: _clock(),
        yearMonth: yearMonth ?? original.yearMonth,
        subject: original.subject,
        operation: operation ?? original.operation,
        employeeId: original.employeeId,
        vehicleId: original.vehicleId,
      );
      _activeBusinessQuestion = original.question;
      await _readBusinessAndAnswer(
        ResolvedIntent(
          action: AttendanceAction.queryBusiness,
          yearMonth: query.yearMonth,
          yearMonthSource: yearMonth == null
              ? AssistantFieldSource.turn
              : AssistantFieldSource.input,
          businessType: query.domain,
          businessQuestion: query.question,
          businessOperation: query.operation,
          businessSubject: query.subject,
          employeeId: query.employeeId,
          vehicleId: query.vehicleId,
        ),
        token: token,
        startedAt: startedAt,
        path: AssistantResolutionPath.localFollowUp,
      );
      return;
    }
    if (message.vehicleQuery case final original?) {
      final year = yearMonth == null
          ? original.year
          : int.parse(yearMonth.substring(0, 4));
      await _readVehicleAndAnswer(
        ResolvedVehicleAnnualRepairQuery(vehicle: original.vehicle, year: year),
        token,
        startedAt,
        path: AssistantResolutionPath.localFollowUp,
      );
    }
  }

  void _clearPendingContexts() {
    _pendingIntent = null;
    _pendingResolutionPath = null;
    _awaitingEmployeeReply = false;
    _pendingPageVehicleSelection = null;
    _pendingCandidateRefs.clear();
    _pendingVehicleCandidateRefs.clear();
  }

  bool _isMonthKind(AssistantQuickQueryKind kind) => switch (kind) {
    AssistantQuickQueryKind.attendance ||
    AssistantQuickQueryKind.payroll ||
    AssistantQuickQueryKind.distribution ||
    AssistantQuickQueryKind.vehicleRepair => true,
    AssistantQuickQueryKind.inventoryLowStock ||
    AssistantQuickQueryKind.purchasePending => false,
  };

  bool _supportsDeterministicBusinessFollowUp(AssistantBusinessType domain) =>
      switch (domain) {
        AssistantBusinessType.attendance ||
        AssistantBusinessType.payroll ||
        AssistantBusinessType.inventory ||
        AssistantBusinessType.purchase ||
        AssistantBusinessType.distribution ||
        AssistantBusinessType.vehicleMaintenance => true,
        AssistantBusinessType.vehicleAnnualRepair ||
        AssistantBusinessType.vehicleAnnualRanking ||
        AssistantBusinessType.vehicleExpenseAnalysis ||
        AssistantBusinessType.personnel ||
        AssistantBusinessType.vehicleReminders ||
        AssistantBusinessType.gardenRepair => false,
      };

  @override
  Future<void> selectCandidate(String candidateRef) async {
    if (_state.isBusy || _candidateInFlight == candidateRef) return;
    final pending = _pendingIntent;
    if (pending == null) return;
    if (_pendingVehicleCandidateRefs.contains(candidateRef)) {
      await _selectVehicleCandidate(candidateRef, pending);
      return;
    }
    if (!_pendingCandidateRefs.contains(candidateRef)) return;
    _pendingCandidateRefs.remove(candidateRef);
    _candidateInFlight = candidateRef;
    final token = _newToken();
    final startedAt = _clock();
    _emit(_copyState(phase: AssistantTurnPhase.resolving));
    try {
      final resolution = await _attendance.resolveCandidate(candidateRef);
      if (!_isCurrent(token)) return;
      if (resolution.status != EmployeeResolutionStatus.unique ||
          resolution.employee == null) {
        _pendingIntent = pending;
        _awaitingEmployeeReply = true;
        _appendError(
          resolution.error ?? AssistantErrorCode.entityUnavailable,
          '所选人员已失效，请重新选择。',
          _pendingResolutionPath ?? AssistantResolutionPath.localFollowUp,
          startedAt,
          token: token,
        );
        return;
      }
      _pendingIntent = null;
      _awaitingEmployeeReply = false;
      _pendingCandidateRefs.clear();
      _pendingVehicleCandidateRefs.clear();
      await _readAndAnswer(
        ResolvedAttendanceQuery(
          employee: resolution.employee!,
          yearMonth: pending.yearMonth!,
          yearMonthSource: pending.yearMonthSource,
          groupId: pending.groupId,
        ),
        token,
        startedAt,
        path: _pendingResolutionPath ?? AssistantResolutionPath.modelParsed,
        parseCalls: 0,
      );
    } catch (_) {
      if (_isCurrent(token)) {
        _pendingIntent = pending;
        _awaitingEmployeeReply = true;
        _appendError(
          AssistantErrorCode.unknown,
          '本地人员复核失败，请重新选择。',
          _pendingResolutionPath ?? AssistantResolutionPath.modelParsed,
          startedAt,
          token: token,
        );
      }
    } finally {
      _candidateInFlight = null;
    }
  }

  @override
  Future<void> refreshResult(String resultRef) async {
    if (_state.isBusy) return;
    final messageId = int.tryParse(resultRef);
    if (messageId == null) return;
    final message = _state.messages
        .where((item) => item.id == messageId)
        .firstOrNull;
    if (message?.answer == null) return;
    final token = _newToken();
    if (message?.localQuery case final previous?) {
      await _readAndAnswer(
        previous,
        token,
        _clock(),
        path: AssistantResolutionPath.localFollowUp,
        parseCalls: 0,
      );
    } else if (message?.vehicleQuery case final vehicleQuery?) {
      await _readVehicleAndAnswer(
        vehicleQuery,
        token,
        _clock(),
        path: AssistantResolutionPath.localFollowUp,
      );
    } else if (message?.expenseQuery case final expenseQuery?) {
      await _runExpenseAnalysis(
        vehicle: expenseQuery.vehicle,
        utterance: '重新查询车辆费用',
        period: expenseQuery.period,
        scope: expenseQuery.scope,
        yearMonth: expenseQuery.yearMonth,
        token: token,
        startedAt: _clock(),
        path: AssistantResolutionPath.localFollowUp,
        parseCalls: 0,
      );
    } else if (message?.businessQuery case final businessQuery?) {
      _activeBusinessQuestion = businessQuery.question;
      await _readBusinessAndAnswer(
        ResolvedIntent(
          action: AttendanceAction.queryBusiness,
          yearMonth: businessQuery.yearMonth,
          yearMonthSource: AssistantFieldSource.turn,
          businessType: businessQuery.domain,
          businessSubject: businessQuery.subject,
          businessOperation: businessQuery.operation,
        ),
        token: token,
        startedAt: _clock(),
        path: AssistantResolutionPath.localFollowUp,
      );
    } else if (message?.rankingQuery case final rankingQuery?) {
      final oldResultRef = message?.answer?.vehicleRanking?.resultRef;
      if (oldResultRef != null) _invalidatedRankingRefs.add(oldResultRef);
      await _readRankingAndAnswer(
        rankingQuery.copyWith(clearResultRef: true, clearCursor: true),
        token,
        _clock(),
        path: AssistantResolutionPath.localFollowUp,
      );
    }
  }

  @override
  Future<void> loadNextVehicleRankingPage(
    String resultRef,
    String cursor,
  ) async {
    final vehicles = _vehicles;
    if (_state.isBusy ||
        vehicles == null ||
        _invalidatedRankingRefs.contains(resultRef)) {
      return;
    }
    final index = _state.messages.lastIndexWhere(
      (message) => message.answer?.vehicleRanking?.resultRef == resultRef,
    );
    if (index < 0) return;
    final message = _state.messages[index];
    final currentPage = message.answer!.vehicleRanking!;
    if (!currentPage.hasMore || currentPage.nextCursor != cursor) return;
    final token = _newToken();
    _emit(_copyState(phase: AssistantTurnPhase.reading));
    try {
      final next = await vehicles.readNextVehicleRankingPage(
        resultRef: resultRef,
        cursor: cursor,
      );
      if (!_isCurrent(token)) return;
      if (next.error != null) {
        _appendError(
          next.error!,
          _vehicleErrorText(next.error!),
          AssistantResolutionPath.localFollowUp,
          _clock(),
          token: token,
        );
        return;
      }
      final combined = VehicleRankingPage(
        resultRef: resultRef,
        year: currentPage.year,
        queriedAt: currentPage.queriedAt,
        rows: [...currentPage.rows, ...next.rows],
        totalVehicleCount: next.totalVehicleCount,
        returnedCount: next.returnedCount,
        hasMore: next.hasMore,
        hasRepairRecords: next.hasRepairRecords,
        nextCursor: next.nextCursor,
        sourceRule: next.sourceRule,
      );
      final answer = _formatter.formatVehicleRanking(combined);
      final updated = AssistantMessage(
        id: message.id,
        text: answer.text,
        isUser: false,
        answer: answer,
        rankingQuery: message.rankingQuery,
        resultRef: resultRef,
        metrics: message.metrics,
      );
      final messages = [..._state.messages];
      messages[index] = updated;
      _emit(_copyState(messages: messages, phase: AssistantTurnPhase.idle));
    } catch (_) {
      if (_isCurrent(token)) {
        _appendError(
          AssistantErrorCode.unknown,
          '本地排名读取失败，请重试。',
          AssistantResolutionPath.localFollowUp,
          _clock(),
          token: token,
        );
      }
    }
  }

  @override
  Future<void> openRankedVehicle(String resultRef, int vehicleId) async {
    if (_state.isBusy ||
        _vehicles == null ||
        _invalidatedRankingRefs.contains(resultRef)) {
      return;
    }
    final source = _state.messages.where((message) {
      final page = message.answer?.vehicleRanking;
      return page?.resultRef == resultRef &&
          page!.rows.any((row) => row.vehicleId == vehicleId);
    }).firstOrNull;
    final row = source?.answer?.vehicleRanking?.rows
        .where((item) => item.vehicleId == vehicleId)
        .firstOrNull;
    if (source == null || row == null) return;
    final vehicle = ResolvedVehicle(
      vehicleId: row.vehicleId,
      label: row.vehicleLabel,
      vehicleNumber: row.vehicleNumber,
    );
    final token = _newToken();
    await _readVehicleAndAnswer(
      ResolvedVehicleAnnualRepairQuery(
        vehicle: vehicle,
        year: source.answer!.vehicleRanking!.year,
      ),
      token,
      _clock(),
      path: AssistantResolutionPath.localFollowUp,
    );
  }

  Future<void> explainAnswer(String resultRef) async {
    if (_state.isBusy) return;
    final messageId = int.tryParse(resultRef);
    if (messageId == null) return;
    final index = _state.messages.indexWhere((item) => item.id == messageId);
    if (index < 0) return;
    final message = _state.messages[index];
    final answer = message.answer;
    if (answer?.businessResult case final business?) {
      final detail = business.facts
          .where((fact) => fact.explanation?.isNotEmpty == true)
          .map((fact) => '${fact.label}：${fact.explanation}')
          .take(6)
          .join('\n');
      final revised = _copyAnswer(
        answer!,
        explanation: detail.isEmpty ? business.summary : detail,
      );
      final messages = [..._state.messages];
      messages[index] = AssistantMessage(
        id: message.id,
        text: message.text,
        isUser: false,
        answer: revised,
        businessQuery: message.businessQuery,
        metrics: message.metrics,
      );
      _emit(_copyState(messages: messages));
      return;
    }
    if (answer == null ||
        answer.error != null ||
        answer.attendanceDays == null ||
        answer.leaveAndRestDays == null ||
        answer.overtimeMinutes == null) {
      return;
    }
    final token = _newToken();
    final explanationStartedAt = _clock();
    _emit(_copyState(phase: AssistantTurnPhase.explaining));
    try {
      final explanation = await _provider.explainSummary(
        AttendanceOutboundSummary(
          yearMonth: answer.yearMonth,
          attendanceDays: answer.attendanceDays!,
          leaveAndRestDays: answer.leaveAndRestDays!,
          overtimeMinutes: answer.overtimeMinutes!,
        ),
        token,
      );
      if (!_isCurrent(token)) return;
      final explanationDuration = _clock().difference(explanationStartedAt);
      final revisedAnswer = _copyAnswer(answer, explanation: explanation.text);
      final usage = _usageDelta(token);
      final messages = [..._state.messages];
      messages[index] = AssistantMessage(
        id: message.id,
        text: message.text,
        isUser: false,
        answer: revisedAnswer,
        candidates: message.candidates,
        error: message.error,
        localQuery: message.localQuery,
        metrics: _metricsAfterExplanation(
          message.metrics,
          usage,
          explanationDuration,
        ),
      );
      _emit(
        _copyState(
          messages: messages,
          phase: AssistantTurnPhase.idle,
          clearPendingRequest: true,
        ),
      );
    } catch (_) {
      if (_isCurrent(token)) {
        final explanationDuration = _clock().difference(explanationStartedAt);
        final usage = _usageDelta(token);
        final messages = [..._state.messages];
        final currentIndex = messages.indexWhere(
          (item) => item.id == messageId,
        );
        if (currentIndex >= 0) {
          final current = messages[currentIndex];
          final currentAnswer = current.answer;
          if (currentAnswer != null) {
            messages[currentIndex] = AssistantMessage(
              id: current.id,
              text: current.text,
              isUser: current.isUser,
              answer: _copyAnswer(currentAnswer, explanation: '文字解释暂不可用'),
              candidates: current.candidates,
              error: current.error,
              localQuery: current.localQuery,
              metrics: _metricsAfterExplanation(
                current.metrics,
                usage,
                explanationDuration,
              ),
            );
          }
        }
        _emit(
          _copyState(
            messages: messages,
            phase: AssistantTurnPhase.idle,
            clearPendingRequest: true,
          ),
        );
      }
    }
  }

  @override
  void updatePageContext(AssistantPageContext? context) {
    final previousVehicleId = _pageContext?.vehicleId;
    if (context != null &&
        (context.vehicleId == null || context.vehicleId != previousVehicleId)) {
      _pendingPageVehicleSelection = context.vehicleId;
    }
    _pageContext = context;
  }

  @override
  void cancelCurrentTask() {
    final token = _state.pendingRequest;
    if (token == null) return;
    token.cancel();
    final partial = _activeExpensePartial;
    final vehicle = _activeExpenseVehicle;
    final expenseQuery = _activeExpenseQuery;
    if (partial != null && vehicle != null) {
      _appendExpenseAnswer(
        partial,
        vehicle,
        _activeExpenseText ?? '车辆费用分析',
        query: expenseQuery,
        stopped: true,
      );
    }
    final expenseSession =
        partial != null && vehicle != null && expenseQuery != null
        ? AssistantSessionContext(
            lastBusinessType: AssistantBusinessType.vehicleExpenseAnalysis,
            lastVehicleExpenseVehicle: vehicle,
            lastVehicleExpenseQuery: expenseQuery,
          )
        : null;
    _activeExpensePartial = null;
    _activeExpenseVehicle = null;
    _activeExpenseQuery = null;
    _activeExpenseText = null;
    _emit(
      _copyState(
        phase: AssistantTurnPhase.idle,
        session: expenseSession,
        clearPendingRequest: true,
        clearAgentProgress: true,
      ),
    );
  }

  @override
  void clearSession() {
    _state.pendingRequest?.cancel();
    _pendingIntent = null;
    _awaitingEmployeeReply = false;
    _pendingResolutionPath = null;
    _pendingCandidateRefs.clear();
    _pendingVehicleCandidateRefs.clear();
    _invalidatedRankingRefs.clear();
    _candidateInFlight = null;
    _emit(const AssistantState());
  }

  Future<void> selectClarificationMonth(String yearMonth) async {
    final pending = _pendingIntent;
    if (pending == null || _state.isBusy || !_validYearMonth(yearMonth)) return;
    _pendingIntent = null;
    _awaitingEmployeeReply = false;
    await _runResolvedIntent(
      pending.copyWith(yearMonth: yearMonth),
      path: _pendingResolutionPath ?? AssistantResolutionPath.localFollowUp,
      token: _newToken(),
      startedAt: _clock(),
    );
  }

  Future<void> _runResolvedIntent(
    ResolvedIntent intent, {
    required AssistantResolutionPath path,
    required RequestToken token,
    required DateTime startedAt,
    int parseCalls = 0,
    Duration? parseDuration,
  }) async {
    if (!_isCurrent(token)) return;
    if (intent.action == AttendanceAction.unsupported) {
      _appendError(
        AssistantErrorCode.unsupported,
        '助手支持查询和分析，修改请到业务页面办理。',
        path,
        startedAt,
        parseCalls: parseCalls,
        parseDuration: parseDuration,
        token: token,
      );
      return;
    }
    if (intent.error != null) {
      _appendError(
        intent.error!,
        intent.businessType == AssistantBusinessType.attendance
            ? '月份或年份无效，请重新说明。'
            : '年份无效，请重新说明年份。',
        path,
        startedAt,
        parseCalls: parseCalls,
        parseDuration: parseDuration,
        token: token,
      );
      return;
    }
    if (_isExtendedBusiness(intent.businessType)) {
      await _readBusinessAndAnswer(
        intent,
        token: token,
        startedAt: startedAt,
        path: path,
        parseCalls: parseCalls,
        parseDuration: parseDuration,
      );
      return;
    }
    if (intent.businessType != AssistantBusinessType.attendance) {
      await _runVehicleResolvedIntent(
        intent,
        path: path,
        token: token,
        startedAt: startedAt,
        parseCalls: parseCalls,
        parseDuration: parseDuration,
      );
      return;
    }
    if (intent.action == AttendanceAction.clarify &&
        intent.yearMonth != null &&
        (intent.employeeText != null || intent.employeeId != null)) {
      _appendError(
        AssistantErrorCode.invalidProviderResponse,
        '未能可靠理解这句话，请换种说法。',
        path,
        startedAt,
        parseCalls: parseCalls,
        parseDuration: parseDuration,
        token: token,
      );
      return;
    }
    if (intent.yearMonth == null ||
        intent.employeeText == null && intent.employeeId == null) {
      _pendingIntent = intent;
      _pendingResolutionPath = path;
      final prompt = intent.employeeText == null && intent.employeeId == null
          ? '要查哪位人员？'
          : '查哪个月？';
      _awaitingEmployeeReply =
          intent.employeeText == null && intent.employeeId == null;
      _appendPrompt(prompt, path, startedAt, parseCalls, parseDuration, token);
      return;
    }
    _emit(_copyState(phase: AssistantTurnPhase.resolving));
    try {
      final resolution = await _attendance.resolveEmployee(
        EmployeeSelector(
          employeeText: intent.employeeText,
          employeeId: intent.employeeId,
          existingEmployee: intent.employeeId != null
              ? ResolvedEmployee(employeeId: intent.employeeId!, label: '')
              : null,
          yearMonth: intent.yearMonth!,
          groupId: intent.groupId,
        ),
      );
      if (!_isCurrent(token)) return;
      switch (resolution.status) {
        case EmployeeResolutionStatus.unique:
          _pendingIntent = null;
          _awaitingEmployeeReply = false;
          final employee = resolution.employee!;
          await _readAndAnswer(
            ResolvedAttendanceQuery(
              employee: employee,
              yearMonth: intent.yearMonth!,
              yearMonthSource: intent.yearMonthSource,
              groupId: intent.groupId,
            ),
            token,
            startedAt,
            path: path,
            parseCalls: parseCalls,
            parseDuration: parseDuration,
          );
        case EmployeeResolutionStatus.candidates:
          _pendingIntent = intent;
          _pendingResolutionPath = path;
          _awaitingEmployeeReply = true;
          _appendCandidates(
            resolution.candidates,
            path,
            startedAt,
            parseCalls,
            parseDuration,
            token,
          );
        case EmployeeResolutionStatus.notFound:
          _pendingIntent = intent;
          _pendingResolutionPath = path;
          _awaitingEmployeeReply = true;
          _appendError(
            resolution.error ?? AssistantErrorCode.entityNotFound,
            '没有找到这位人员，请检查姓名或编号。',
            path,
            startedAt,
            parseCalls: parseCalls,
            parseDuration: parseDuration,
            token: token,
          );
        case EmployeeResolutionStatus.unavailable:
          _appendError(
            resolution.error ?? AssistantErrorCode.entityUnavailable,
            '该人员已失效，请重新选择。',
            path,
            startedAt,
            token: token,
            parseCalls: parseCalls,
            parseDuration: parseDuration,
          );
      }
    } catch (_) {
      if (_isCurrent(token)) {
        _appendError(
          AssistantErrorCode.unknown,
          '本地人员查询失败，请重试。',
          path,
          startedAt,
          token: token,
          parseCalls: parseCalls,
          parseDuration: parseDuration,
        );
      }
    }
  }

  Future<void> _runVehicleResolvedIntent(
    ResolvedIntent intent, {
    required AssistantResolutionPath path,
    required RequestToken token,
    required DateTime startedAt,
    int parseCalls = 0,
    Duration? parseDuration,
  }) async {
    if (!_isCurrent(token)) return;
    final vehicles = _vehicles;
    if (vehicles == null) {
      _appendError(
        AssistantErrorCode.unsupported,
        '车辆查询暂不可用，请从车辆页面查看。',
        path,
        startedAt,
        parseCalls: parseCalls,
        parseDuration: parseDuration,
        token: token,
      );
      return;
    }
    if (intent.businessType == AssistantBusinessType.vehicleExpenseAnalysis) {
      final vehicleText = intent.vehicleText;
      final vehicleId = intent.vehicleId;
      if (vehicleText == null && vehicleId == null) {
        _pendingIntent = intent;
        _pendingResolutionPath = path;
        _awaitingEmployeeReply = true;
        _appendPrompt(
          '要查哪辆车？',
          path,
          startedAt,
          parseCalls,
          parseDuration,
          token,
        );
        return;
      }
      _emit(_copyState(phase: AssistantTurnPhase.resolving));
      try {
        final resolution = await vehicles.resolveVehicle(
          VehicleSelector(vehicleText: vehicleText, vehicleId: vehicleId),
        );
        if (!_isCurrent(token)) return;
        switch (resolution.status) {
          case VehicleResolutionStatus.unique:
            final vehicle = resolution.vehicle;
            if (vehicle == null) {
              _appendError(
                AssistantErrorCode.entityUnavailable,
                '该车辆已失效，请重新选择。',
                path,
                startedAt,
                token: token,
              );
              return;
            }
            _pendingIntent = null;
            _awaitingEmployeeReply = false;
            await _runExpenseAnalysis(
              vehicle: vehicle,
              utterance: _activeExpenseText ?? '',
              period: intent.expensePeriod,
              scope: intent.expenseCategory,
              yearMonth: intent.expenseYearMonth,
              token: token,
              startedAt: startedAt,
              path: path,
              parseCalls: parseCalls,
              parseDuration: parseDuration,
            );
          case VehicleResolutionStatus.candidates:
            _pendingIntent = intent;
            _pendingResolutionPath = path;
            _awaitingEmployeeReply = true;
            _appendVehicleCandidates(
              resolution.candidates,
              path,
              startedAt,
              parseCalls,
              parseDuration,
              token,
            );
          case VehicleResolutionStatus.notFound:
            _pendingIntent = intent;
            _pendingResolutionPath = path;
            _awaitingEmployeeReply = true;
            _appendError(
              resolution.error ?? AssistantErrorCode.entityNotFound,
              '没有找到这辆车，请检查名称或编号。',
              path,
              startedAt,
              parseCalls: parseCalls,
              parseDuration: parseDuration,
              token: token,
            );
          case VehicleResolutionStatus.unavailable:
            _appendError(
              resolution.error ?? AssistantErrorCode.entityUnavailable,
              '车辆已失效，请重新选择。',
              path,
              startedAt,
              token: token,
            );
        }
      } catch (_) {
        if (_isCurrent(token)) {
          _appendError(
            AssistantErrorCode.unknown,
            '本地车辆查询失败，请重试。',
            path,
            startedAt,
            parseCalls: parseCalls,
            parseDuration: parseDuration,
            token: token,
          );
        }
      }
      return;
    }
    final year = intent.requestedYear;
    if (year == null || year < 1 || year > 9999) {
      _appendError(
        AssistantErrorCode.invalidArgument,
        '年份无效，请重新说明年份。',
        path,
        startedAt,
        parseCalls: parseCalls,
        parseDuration: parseDuration,
        token: token,
      );
      return;
    }
    if (intent.businessType == AssistantBusinessType.vehicleAnnualRanking) {
      await _readRankingAndAnswer(
        ResolvedVehicleRankingQuery(year: year),
        token,
        startedAt,
        path: path,
        parseCalls: parseCalls,
        parseDuration: parseDuration,
      );
      return;
    }
    final vehicleText = intent.vehicleText;
    final vehicleId = intent.vehicleId;
    if (vehicleText == null && vehicleId == null) {
      _pendingIntent = intent;
      _pendingResolutionPath = path;
      _awaitingEmployeeReply = true;
      _appendPrompt(
        '要查哪辆车？',
        path,
        startedAt,
        parseCalls,
        parseDuration,
        token,
      );
      return;
    }
    _emit(_copyState(phase: AssistantTurnPhase.resolving));
    try {
      final resolution = await vehicles.resolveVehicle(
        VehicleSelector(vehicleText: vehicleText, vehicleId: vehicleId),
      );
      if (!_isCurrent(token)) return;
      switch (resolution.status) {
        case VehicleResolutionStatus.unique:
          final vehicle = resolution.vehicle;
          if (vehicle == null) {
            _appendError(
              AssistantErrorCode.entityUnavailable,
              '该车辆已失效，请重新选择。',
              path,
              startedAt,
              token: token,
            );
            return;
          }
          _pendingIntent = null;
          _awaitingEmployeeReply = false;
          _pendingVehicleCandidateRefs.clear();
          await _readVehicleAndAnswer(
            ResolvedVehicleAnnualRepairQuery(vehicle: vehicle, year: year),
            token,
            startedAt,
            path: path,
            parseCalls: parseCalls,
            parseDuration: parseDuration,
          );
        case VehicleResolutionStatus.candidates:
          _pendingIntent = intent;
          _pendingResolutionPath = path;
          _awaitingEmployeeReply = true;
          _appendVehicleCandidates(
            resolution.candidates,
            path,
            startedAt,
            parseCalls,
            parseDuration,
            token,
          );
        case VehicleResolutionStatus.notFound:
          _pendingIntent = intent;
          _pendingResolutionPath = path;
          _awaitingEmployeeReply = true;
          _appendError(
            resolution.error ?? AssistantErrorCode.entityNotFound,
            '没有找到这辆车，请检查名称、编号或车牌。',
            path,
            startedAt,
            parseCalls: parseCalls,
            parseDuration: parseDuration,
            token: token,
          );
        case VehicleResolutionStatus.unavailable:
          _appendError(
            resolution.error ?? AssistantErrorCode.entityUnavailable,
            '车辆已失效，请重新选择。',
            path,
            startedAt,
            parseCalls: parseCalls,
            parseDuration: parseDuration,
            token: token,
          );
      }
    } catch (_) {
      if (_isCurrent(token)) {
        _appendError(
          AssistantErrorCode.unknown,
          '本地车辆查询失败，请重试。',
          path,
          startedAt,
          parseCalls: parseCalls,
          parseDuration: parseDuration,
          token: token,
        );
      }
    }
  }

  Future<void> _selectVehicleCandidate(
    String candidateRef,
    ResolvedIntent pending,
  ) async {
    _pendingVehicleCandidateRefs.remove(candidateRef);
    _candidateInFlight = candidateRef;
    final token = _newToken();
    final startedAt = _clock();
    _emit(_copyState(phase: AssistantTurnPhase.resolving));
    try {
      final resolution = await _vehicles?.resolveVehicleCandidate(candidateRef);
      if (!_isCurrent(token)) return;
      final vehicle = resolution?.vehicle;
      if (resolution?.status != VehicleResolutionStatus.unique ||
          vehicle == null) {
        _pendingIntent = pending;
        _awaitingEmployeeReply = true;
        _appendError(
          resolution?.error ?? AssistantErrorCode.entityUnavailable,
          '所选车辆已失效，请重新选择。',
          _pendingResolutionPath ?? AssistantResolutionPath.localFollowUp,
          startedAt,
          token: token,
        );
        return;
      }
      if (pending.businessType ==
          AssistantBusinessType.vehicleExpenseAnalysis) {
        _pendingIntent = null;
        _awaitingEmployeeReply = false;
        _pendingVehicleCandidateRefs.clear();
        await _runExpenseAnalysis(
          vehicle: vehicle,
          utterance: _activeExpenseText ?? '分析这辆车的费用',
          period: pending.expensePeriod,
          scope: pending.expenseCategory,
          yearMonth: pending.expenseYearMonth,
          token: token,
          startedAt: startedAt,
          path: _pendingResolutionPath ?? AssistantResolutionPath.modelParsed,
        );
        return;
      }
      final year = pending.requestedYear;
      if (year == null) return;
      _pendingIntent = null;
      _awaitingEmployeeReply = false;
      _pendingVehicleCandidateRefs.clear();
      await _readVehicleAndAnswer(
        ResolvedVehicleAnnualRepairQuery(vehicle: vehicle, year: year),
        token,
        startedAt,
        path: _pendingResolutionPath ?? AssistantResolutionPath.modelParsed,
      );
    } catch (_) {
      if (_isCurrent(token)) {
        _pendingIntent = pending;
        _awaitingEmployeeReply = true;
        _appendError(
          AssistantErrorCode.unknown,
          '本地车辆复核失败，请重新选择。',
          _pendingResolutionPath ?? AssistantResolutionPath.modelParsed,
          startedAt,
          token: token,
        );
      }
    } finally {
      _candidateInFlight = null;
    }
  }

  Future<void> _runExpenseAnalysis({
    required ResolvedVehicle vehicle,
    required String utterance,
    required AssistantAgentPeriod period,
    required VehicleExpenseCategoryScope scope,
    required RequestToken token,
    required DateTime startedAt,
    required AssistantResolutionPath path,
    String? yearMonth,
    int parseCalls = 0,
    Duration? parseDuration,
  }) async {
    final reader = _expenseReader;
    final provider = _provider;
    if (reader == null || provider is! VehicleExpenseAgentProvider) {
      _appendError(
        AssistantErrorCode.unsupported,
        '车辆费用分析暂不可用。',
        path,
        startedAt,
        parseCalls: parseCalls,
        parseDuration: parseDuration,
        token: token,
      );
      return;
    }
    _activeExpensePartial = null;
    _activeExpenseVehicle = vehicle;
    _activeExpenseText = utterance;
    final query = ResolvedVehicleExpenseQuery(
      vehicle: vehicle,
      period: period,
      scope: scope,
      yearMonth: yearMonth,
    );
    _activeExpenseQuery = query;
    _expenseRunner ??= AssistantVehicleExpenseRunner(
      provider: provider as VehicleExpenseAgentProvider,
      reader: reader,
      clock: _clock,
    );
    _emit(
      _copyState(phase: AssistantTurnPhase.reading, agentProgress: '正在分析费用需求'),
    );
    final runnerResult = await _expenseRunner!.run(
      utterance: utterance,
      vehicleId: vehicle.vehicleId,
      period: period,
      scope: scope,
      yearMonth: yearMonth,
      token: token,
      taskStartedAt: startedAt,
      priorModelRequests: parseCalls,
      onProgress: (label) {
        if (_isCurrent(token)) {
          _emit(
            _copyState(phase: AssistantTurnPhase.reading, agentProgress: label),
          );
        }
      },
      onPartial: (partial) {
        if (_isCurrent(token)) {
          _activeExpensePartial = _expenseAnswer(vehicle, partial);
        }
      },
    );
    if (!identical(_state.pendingRequest, token) ||
        token.isCancelled &&
            runnerResult.failure != AssistantErrorCode.timeout) {
      return;
    }
    final answer = _expenseAnswer(vehicle, runnerResult);
    final message = _appendExpenseAnswer(
      answer,
      vehicle,
      utterance,
      query: query,
      path: path,
      token: token,
      startedAt: startedAt,
      parseCalls: parseCalls,
      parseDuration: parseDuration,
    );
    final session = AssistantSessionContext(
      lastBusinessType: AssistantBusinessType.vehicleExpenseAnalysis,
      lastVehicleExpenseVehicle: vehicle,
      lastVehicleExpenseQuery: query,
    );
    final messages = [..._state.messages];
    final last = messages.lastIndexWhere((item) => item.id == message.id);
    if (last >= 0) {
      messages[last] = AssistantMessage(
        id: message.id,
        text: message.text,
        isUser: false,
        answer: message.answer,
        expenseQuery: query,
        metrics: message.metrics,
      );
    }
    _activeExpensePartial = null;
    _activeExpenseVehicle = null;
    _activeExpenseQuery = null;
    _activeExpenseText = null;
    _emit(
      _copyState(
        messages: messages,
        phase: AssistantTurnPhase.idle,
        session: session,
        clearPendingRequest: true,
        clearAgentProgress: true,
        lastResolutionPath: path,
      ),
    );
  }

  VehicleExpenseAnalysisAnswer _expenseAnswer(
    ResolvedVehicle vehicle,
    AssistantAgentRunResult result,
  ) {
    final summary = _localExpenseSummary(result);
    final qualitative = result.summaryText;
    final hasNumericClaim =
        qualitative != null &&
        RegExp(r'[0-9０-９零〇一二三四五六七八九十百千万亿两]').hasMatch(qualitative);
    return VehicleExpenseAnalysisAnswer(
      vehicleId: vehicle.vehicleId,
      vehicleLabel: vehicle.label,
      resultRef: _nextMessageId.toString(),
      summaryText: hasNumericClaim || qualitative == null
          ? summary
          : '$summary\n$qualitative',
      periods: result.periods,
      evidence: result.evidence,
      peerComparisons: result.peerComparisons,
      executedTools: result.executedTools,
      failure: result.failure,
      stopped: result.stopped,
      sourceRule: 'vehicle_expense_aggregate_v1',
      sourcePage: 'vehicle_expense_tab',
    );
  }

  String _localExpenseSummary(AssistantAgentRunResult result) {
    final positives =
        result.evidence
            .where((item) => item.deltaCents != null && item.deltaCents! > 0)
            .toList()
          ..sort((a, b) => b.deltaCents!.compareTo(a.deltaCents!));
    final peer = result.peerComparisons.lastOrNull;
    if (peer?.metricUnit != null &&
        peer?.targetUnitCost != null &&
        peer?.peerUnitCost != null) {
      final metricLabel = switch (peer!.metricUnit!) {
        VehicleExpenseWorkloadMetric.mileage => '公里',
        VehicleExpenseWorkloadMetric.workHours => '小时',
        VehicleExpenseWorkloadMetric.workDays => '工作日',
      };
      return '在同车型、同期间的可比记录中，本车单位$metricLabel登记费用为${peer.targetUnitCost!.toStringAsFixed(1)}分，对照均值为${peer.peerUnitCost!.toStringAsFixed(1)}分；仅作参考，登记覆盖及工作量可比性见依据。';
    }
    if (positives.isNotEmpty) {
      final main = positives.first;
      final label = _expenseCategoryLabel(main.label);
      final amount = _formatCents(main.deltaCents!);
      final share = main.contributionPercent == null
          ? ''
          : '，占已比较类别净增长的${main.contributionPercent!.toStringAsFixed(1)}%';
      return '费用登记变化主要来自$label，较对比期增加$amount$share；这是台账金额差异，不足以单独判断异常原因。';
    }
    final count = result.periods.fold<int>(
      0,
      (sum, period) =>
          sum +
          period.fuelMonths.length +
          period.categories.fold<int>(
            0,
            (inner, item) => inner + item.recordCount,
          ),
    );
    if (count == 0) {
      return result.periods.isNotEmpty
          ? '已取得本期费用查询结果，但没有登记记录；未登记不能据此认定实际没有支出。'
          : '当前没有取得费用数据，暂时无法判断费用变化。';
    }
    if (!result.evidence.any((item) => item.deltaCents != null)) {
      return '已读取本期登记费用，但尚未取得可比前期，暂不能判断费用是否增加。';
    }
    if (result.failure != null) {
      return '已保留查询到的本地费用依据；其余查询未完成，当前不能判断费用变化。';
    }
    return '当前登记数据没有显示明确的费用增长；登记覆盖信息有限，结论仅反映现有台账。';
  }

  String _expenseCategoryLabel(String value) => switch (value) {
    'repair' => '维修费用',
    'maintenance' => '保养费用',
    'fuel' => '油费',
    'manual' => '其他费用',
    _ => value,
  };

  String _formatCents(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';

  AssistantMessage _appendExpenseAnswer(
    VehicleExpenseAnalysisAnswer expense,
    ResolvedVehicle vehicle,
    String utterance, {
    ResolvedVehicleExpenseQuery? query,
    AssistantResolutionPath path = AssistantResolutionPath.modelParsed,
    RequestToken? token,
    DateTime? startedAt,
    int parseCalls = 0,
    Duration? parseDuration,
    bool stopped = false,
  }) {
    final finalExpense = stopped
        ? VehicleExpenseAnalysisAnswer(
            vehicleId: expense.vehicleId,
            vehicleLabel: expense.vehicleLabel,
            resultRef: expense.resultRef,
            summaryText: expense.summaryText,
            periods: expense.periods,
            evidence: expense.evidence,
            peerComparisons: expense.peerComparisons,
            executedTools: expense.executedTools,
            sourceRule: expense.sourceRule,
            sourcePage: expense.sourcePage,
            failure: expense.failure,
            stopped: true,
          )
        : expense;
    final text = stopped
        ? '已停止查询，已取得的费用依据保留如下。\n${expense.summaryText}'
        : expense.summaryText;
    final answer = AssistantAnswer(
      text: text,
      employeeLabel: '',
      yearMonth: '',
      queriedAt: _clock(),
      completeness: AttendanceCompleteness.notEvaluated,
      yearMonthSource: AssistantFieldSource.none,
      sourceRule: expense.sourceRule,
      sourcePage: expense.sourcePage,
      vehicleExpenseAnalysis: finalExpense,
      error: finalExpense.failure,
    );
    final message = AssistantMessage(
      id: _nextMessageId++,
      text: text,
      isUser: false,
      answer: answer,
      expenseQuery: ResolvedVehicleExpenseQuery(
        vehicle: query?.vehicle ?? vehicle,
        period: query?.period ?? AssistantAgentPeriod.recent30Days,
        scope: query?.scope ?? VehicleExpenseCategoryScope.all,
        yearMonth: query?.yearMonth,
      ),
      metrics: token == null
          ? null
          : _metrics(
              token,
              path: path,
              parseCalls: parseCalls,
              parseDuration: parseDuration,
              localReadDuration: _clock().difference(startedAt ?? _clock()),
              elapsed: _clock().difference(startedAt ?? _clock()),
            ),
    );
    _emit(_copyState(messages: [..._state.messages, message]));
    return message;
  }

  Future<void> _readAndAnswer(
    ResolvedAttendanceQuery query,
    RequestToken token,
    DateTime startedAt, {
    required AssistantResolutionPath path,
    int parseCalls = 0,
    Duration? parseDuration,
  }) async {
    _emit(_copyState(phase: AssistantTurnPhase.reading));
    final readStarted = _clock();
    try {
      final result = await _attendance.readMonth(query);
      if (!_isCurrent(token)) return;
      final answer = _formatter.formatAnswer(
        result,
        yearMonthSource: query.yearMonthSource,
      );
      final message = AssistantMessage(
        id: _nextMessageId++,
        text: answer.text,
        isUser: false,
        answer: answer,
        localQuery: query,
        metrics: _metrics(
          token,
          path: path,
          parseCalls: parseCalls,
          parseDuration: parseDuration,
          localReadDuration: _clock().difference(readStarted),
          elapsed: _clock().difference(startedAt),
        ),
      );
      _emit(
        _copyState(
          messages: [..._state.messages, message],
          phase: AssistantTurnPhase.idle,
          session:
              result.status == AttendanceReadStatus.success ||
                  result.status == AttendanceReadStatus.notInRoster
              ? AssistantSessionContext(lastQuery: query)
              : _state.session,
          pendingRequest: null,
          clearPendingRequest: true,
          lastResolutionPath: path,
        ),
      );
    } catch (_) {
      if (_isCurrent(token)) {
        _appendError(
          AssistantErrorCode.unknown,
          '本地考勤读取失败，请重试。',
          path,
          startedAt,
          parseCalls: parseCalls,
          parseDuration: parseDuration,
          localReadDuration: _clock().difference(readStarted),
          token: token,
        );
      }
    }
  }

  Future<void> _readBusinessAndAnswer(
    ResolvedIntent intent, {
    required RequestToken token,
    required DateTime startedAt,
    required AssistantResolutionPath path,
    int parseCalls = 0,
    Duration? parseDuration,
  }) async {
    final reader = _businessReader;
    if (reader == null) {
      _appendError(AssistantErrorCode.entityUnavailable, '当前业务查询暂不可用。', path, startedAt, token: token);
      return;
    }
    _emit(_copyState(phase: AssistantTurnPhase.reading));
    final readStarted = _clock();
    final query = AssistantBusinessQuery(
      domain: intent.businessType,
      question: _activeBusinessQuestion ?? intent.businessQuestion ?? '',
      now: _clock(),
      yearMonth: intent.yearMonth,
      subject: intent.businessSubject,
      operation: intent.businessOperation,
      employeeId: intent.businessType == AssistantBusinessType.personnel ||
              intent.businessType == AssistantBusinessType.payroll ||
              intent.businessType == AssistantBusinessType.attendance
          ? intent.employeeId
          : null,
      vehicleId: intent.vehicleId,
    );
    try {
      final result = await reader.read(query);
      if (!_isCurrent(token)) return;
      final text = '${result.summary}${result.facts.isEmpty ? '' : '\n${result.facts.map((fact) => '${fact.label}：${fact.value}').join('\n')}'}';
      final answer = AssistantAnswer(
        text: text,
        employeeLabel: result.title,
        yearMonth: query.yearMonth ?? '',
        queriedAt: result.queriedAt,
        completeness: AttendanceCompleteness.notEvaluated,
        yearMonthSource: intent.yearMonthSource,
        sourceRule: result.sourceRule,
        sourcePage: result.sourcePage,
        businessResult: result,
        error: result.error,
      );
      final message = AssistantMessage(
        id: _nextMessageId++,
        text: text,
        isUser: false,
        answer: answer,
        businessQuery: query,
        metrics: _metrics(token, path: path, parseCalls: parseCalls, parseDuration: parseDuration, localReadDuration: _clock().difference(readStarted), elapsed: _clock().difference(startedAt)),
      );
      final previous = _state.session;
      _emit(_copyState(
        messages: [..._state.messages, message],
        phase: AssistantTurnPhase.idle,
        session: AssistantSessionContext(
          lastQuery: previous.lastQuery,
          pendingQuery: previous.pendingQuery,
          pendingEmployeeQuery: previous.pendingEmployeeQuery,
          selectedCandidateRefs: previous.selectedCandidateRefs,
          lastBusinessType: intent.businessType,
          lastVehicleQuery: previous.lastVehicleQuery,
          lastRankingQuery: previous.lastRankingQuery,
          lastVehicleExpenseVehicle: previous.lastVehicleExpenseVehicle,
          lastVehicleExpenseQuery: previous.lastVehicleExpenseQuery,
          lastBusinessQuestion: query.question,
          lastBusinessQuery: query,
        ),
        clearPendingRequest: true,
        lastResolutionPath: path,
      ));
    } catch (_) {
      if (_isCurrent(token)) {
        _appendError(AssistantErrorCode.unknown, '本地业务读取失败，请重试。', path, startedAt, parseCalls: parseCalls, parseDuration: parseDuration, localReadDuration: _clock().difference(readStarted), token: token);
      }
    }
  }

  bool _isExtendedBusiness(AssistantBusinessType type) => switch (type) {
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

  Future<void> _readVehicleAndAnswer(
    ResolvedVehicleAnnualRepairQuery query,
    RequestToken token,
    DateTime startedAt, {
    required AssistantResolutionPath path,
    int parseCalls = 0,
    Duration? parseDuration,
  }) async {
    final vehicles = _vehicles;
    if (vehicles == null) return;
    _emit(_copyState(phase: AssistantTurnPhase.reading));
    final readStarted = _clock();
    try {
      final result = await vehicles.readVehicleAnnualRepairs(query);
      if (!_isCurrent(token)) return;
      final answer = _formatter.formatVehicleSummary(result);
      final session =
          result.status == VehicleAnnualRepairReadStatus.success ||
              result.status == VehicleAnnualRepairReadStatus.empty
          ? AssistantSessionContext(
              lastBusinessType: AssistantBusinessType.vehicleAnnualRepair,
              lastVehicleQuery: query,
            )
          : _state.session;
      final message = AssistantMessage(
        id: _nextMessageId++,
        text: answer.text,
        isUser: false,
        answer: answer,
        vehicleQuery: query,
        resultRef: result.resultRef,
        metrics: _metrics(
          token,
          path: path,
          parseCalls: parseCalls,
          parseDuration: parseDuration,
          localReadDuration: _clock().difference(readStarted),
          elapsed: _clock().difference(startedAt),
        ),
      );
      _emit(
        _copyState(
          messages: [..._state.messages, message],
          phase: AssistantTurnPhase.idle,
          session: session,
          pendingRequest: null,
          clearPendingRequest: true,
          lastResolutionPath: path,
        ),
      );
    } catch (_) {
      if (_isCurrent(token)) {
        _appendError(
          AssistantErrorCode.unknown,
          '本地车辆维修汇总读取失败，请重试。',
          path,
          startedAt,
          parseCalls: parseCalls,
          parseDuration: parseDuration,
          localReadDuration: _clock().difference(readStarted),
          token: token,
        );
      }
    }
  }

  Future<void> _readRankingAndAnswer(
    ResolvedVehicleRankingQuery query,
    RequestToken token,
    DateTime startedAt, {
    required AssistantResolutionPath path,
    int parseCalls = 0,
    Duration? parseDuration,
  }) async {
    final vehicles = _vehicles;
    if (vehicles == null) return;
    _emit(_copyState(phase: AssistantTurnPhase.reading));
    final readStarted = _clock();
    try {
      final result = await vehicles.readAnnualVehicleRanking(query);
      if (!_isCurrent(token)) return;
      final answer = _formatter.formatVehicleRanking(result);
      final updatedQuery = ResolvedVehicleRankingQuery(
        year: result.year,
        limit: query.limit,
        resultRef: result.resultRef,
        cursor: result.nextCursor,
      );
      final session = result.error == null
          ? AssistantSessionContext(
              lastBusinessType: AssistantBusinessType.vehicleAnnualRanking,
              lastRankingQuery: updatedQuery,
            )
          : _state.session;
      final message = AssistantMessage(
        id: _nextMessageId++,
        text: answer.text,
        isUser: false,
        answer: answer,
        rankingQuery: updatedQuery,
        resultRef: result.resultRef,
        metrics: _metrics(
          token,
          path: path,
          parseCalls: parseCalls,
          parseDuration: parseDuration,
          localReadDuration: _clock().difference(readStarted),
          elapsed: _clock().difference(startedAt),
        ),
      );
      _emit(
        _copyState(
          messages: [..._state.messages, message],
          phase: AssistantTurnPhase.idle,
          session: session,
          pendingRequest: null,
          clearPendingRequest: true,
          lastResolutionPath: path,
        ),
      );
    } catch (_) {
      if (_isCurrent(token)) {
        _appendError(
          AssistantErrorCode.unknown,
          '本地车辆排名读取失败，请重试。',
          path,
          startedAt,
          parseCalls: parseCalls,
          parseDuration: parseDuration,
          localReadDuration: _clock().difference(readStarted),
          token: token,
        );
      }
    }
  }

  void _appendVehicleCandidates(
    List<VehicleCandidate> candidates,
    AssistantResolutionPath path,
    DateTime startedAt,
    int parseCalls,
    Duration? parseDuration,
    RequestToken token,
  ) {
    _pendingVehicleCandidateRefs
      ..clear()
      ..addAll(candidates.map((candidate) => candidate.candidateRef));
    _emit(
      _copyState(
        messages: [
          ..._state.messages,
          AssistantMessage(
            id: _nextMessageId++,
            text: candidates.length == 1
                ? '找到可能的车辆，请确认。'
                : '找到多辆可能的车辆，请选择一辆。',
            isUser: false,
            vehicleCandidates: candidates,
            metrics: _metrics(
              token,
              path: path,
              parseCalls: parseCalls,
              parseDuration: parseDuration,
              elapsed: _clock().difference(startedAt),
            ),
          ),
        ],
        phase: AssistantTurnPhase.idle,
        pendingRequest: null,
        clearPendingRequest: true,
        lastResolutionPath: path,
      ),
    );
  }

  RequestToken _newToken() {
    final token = RequestToken();
    _emit(_copyState(pendingRequest: token, lastResolutionPath: null));
    return token;
  }

  ({int? calls, int? inputTokens, int? outputTokens, Duration? duration})
  _usageDelta(RequestToken token) {
    if (_provider is! AIProviderUsage) {
      return (
        calls: null,
        inputTokens: null,
        outputTokens: null,
        duration: null,
      );
    }
    final requestUsage = (_provider as AIProviderUsage).usageForRequest(
      token.id,
    );
    return (
      calls: requestUsage.requestCount,
      inputTokens: requestUsage.inputTokens,
      outputTokens: requestUsage.outputTokens,
      duration: requestUsage.totalDuration,
    );
  }

  AssistantTurnMetrics? _metricsAfterExplanation(
    AssistantTurnMetrics? metrics,
    _ProviderUsageDelta usage,
    Duration explanationDuration,
  ) {
    if (metrics == null) return null;
    return AssistantTurnMetrics(
      resolutionPath: metrics.resolutionPath,
      parseCalls: metrics.parseCalls,
      explanationCalls: metrics.explanationCalls + 1,
      parseDuration: metrics.parseDuration,
      localReadDuration: metrics.localReadDuration,
      elapsed: metrics.elapsed == null
          ? null
          : metrics.elapsed! + explanationDuration,
      providerCalls:
          (metrics.providerCalls ??
              metrics.parseCalls + metrics.explanationCalls) +
          (usage.calls ?? 1),
      inputTokens: _accumulateKnown(metrics.inputTokens, usage.inputTokens),
      outputTokens: _accumulateKnown(metrics.outputTokens, usage.outputTokens),
      providerDuration: usage.duration == null
          ? metrics.providerDuration
          : (metrics.providerDuration ?? Duration.zero) + usage.duration!,
    );
  }

  int? _accumulateKnown(int? current, int? delta) =>
      delta == null ? current : (current ?? 0) + delta;

  AssistantTurnMetrics _metrics(
    RequestToken token, {
    required AssistantResolutionPath path,
    int parseCalls = 0,
    int explanationCalls = 0,
    Duration? parseDuration,
    Duration? localReadDuration,
    Duration? elapsed,
  }) {
    final usage = _usageDelta(token);
    return AssistantTurnMetrics(
      resolutionPath: path,
      parseCalls: parseCalls,
      explanationCalls: explanationCalls,
      parseDuration: parseDuration,
      localReadDuration: localReadDuration,
      elapsed: elapsed,
      providerCalls: usage.calls ?? parseCalls + explanationCalls,
      inputTokens: usage.inputTokens,
      outputTokens: usage.outputTokens,
      providerDuration: usage.duration,
    );
  }

  String _providerErrorText(AssistantErrorCode code) => switch (code) {
    AssistantErrorCode.missingApiKey => '请先在助手设置中配置 API Key。',
    AssistantErrorCode.unauthorized => 'API Key 无效，请检查助手设置。',
    AssistantErrorCode.rateLimited => '请求过于频繁，请稍后再试。',
    AssistantErrorCode.timeout => '请求超时，请检查网络后重试。',
    AssistantErrorCode.network => '网络连接失败，请检查网络后重试。',
    AssistantErrorCode.invalidProviderResponse => '未能可靠理解这句话，请换种说法。',
    _ => '助手服务暂不可用，请稍后重试。',
  };

  String _vehicleErrorText(AssistantErrorCode code) => switch (code) {
    AssistantErrorCode.entityNotFound => '没有找到这辆车，请重新查询。',
    AssistantErrorCode.entityUnavailable => '该车辆已失效，请重新选择。',
    AssistantErrorCode.invalidArgument => '年份或分页条件无效，请重新查询。',
    _ => '排名结果已失效，请重新查询。',
  };

  bool _isCurrent(RequestToken token) =>
      identical(_state.pendingRequest, token) && !token.isCancelled;

  void _appendCandidates(
    List<EmployeeCandidate> candidates,
    AssistantResolutionPath path,
    DateTime startedAt,
    int parseCalls,
    Duration? parseDuration,
    RequestToken token,
  ) {
    _pendingCandidateRefs
      ..clear()
      ..addAll(candidates.map((candidate) => candidate.candidateRef));
    _emit(
      _copyState(
        messages: [
          ..._state.messages,
          AssistantMessage(
            id: _nextMessageId++,
            text: candidates.length == 1
                ? '找到可能的人员，请确认。'
                : '找到多位可能的人员，请选择一位。',
            isUser: false,
            candidates: candidates,
            metrics: _metrics(
              token,
              path: path,
              parseCalls: parseCalls,
              parseDuration: parseDuration,
              elapsed: _clock().difference(startedAt),
            ),
          ),
        ],
        phase: AssistantTurnPhase.idle,
        pendingRequest: null,
        clearPendingRequest: true,
        lastResolutionPath: path,
      ),
    );
  }

  void _appendPrompt(
    String text,
    AssistantResolutionPath path,
    DateTime startedAt,
    int parseCalls,
    Duration? parseDuration,
    RequestToken token,
  ) {
    _emit(
      _copyState(
        messages: [
          ..._state.messages,
          AssistantMessage(
            id: _nextMessageId++,
            text: text,
            isUser: false,
            metrics: _metrics(
              token,
              path: path,
              parseCalls: parseCalls,
              parseDuration: parseDuration,
              elapsed: _clock().difference(startedAt),
            ),
          ),
        ],
        phase: AssistantTurnPhase.idle,
        pendingRequest: null,
        clearPendingRequest: true,
        lastResolutionPath: path,
      ),
    );
  }

  void _appendError(
    AssistantErrorCode error,
    String text,
    AssistantResolutionPath path,
    DateTime startedAt, {
    int parseCalls = 0,
    Duration? parseDuration,
    Duration? localReadDuration,
    RequestToken? token,
  }) {
    final metrics = token == null
        ? AssistantTurnMetrics(
            resolutionPath: path,
            parseCalls: parseCalls,
            parseDuration: parseDuration,
            localReadDuration: localReadDuration,
            elapsed: _clock().difference(startedAt),
          )
        : _metrics(
            token,
            path: path,
            parseCalls: parseCalls,
            parseDuration: parseDuration,
            localReadDuration: localReadDuration,
            elapsed: _clock().difference(startedAt),
          );
    _emit(
      _copyState(
        messages: [
          ..._state.messages,
          AssistantMessage(
            id: _nextMessageId++,
            text: text,
            isUser: false,
            error: error,
            metrics: metrics,
          ),
        ],
        phase: AssistantTurnPhase.idle,
        pendingRequest: null,
        clearPendingRequest: true,
        lastResolutionPath: path,
      ),
    );
  }

  void _emit(AssistantState state) {
    _state = state;
    onStateChanged?.call(state);
  }

  AssistantState _copyState({
    List<AssistantMessage>? messages,
    AssistantTurnPhase? phase,
    AssistantSessionContext? session,
    RequestToken? pendingRequest,
    bool clearPendingRequest = false,
    AssistantResolutionPath? lastResolutionPath,
    String? agentProgress,
    bool clearAgentProgress = false,
  }) => AssistantState(
    messages: messages ?? _state.messages,
    phase: phase ?? _state.phase,
    session: session ?? _state.session,
    pendingRequest: clearPendingRequest
        ? null
        : pendingRequest ?? _state.pendingRequest,
    lastResolutionPath: lastResolutionPath ?? _state.lastResolutionPath,
    agentProgress: clearAgentProgress
        ? null
        : agentProgress ?? _state.agentProgress,
  );

  AssistantSessionContext _sessionForPageVehicleSelection(
    AssistantSessionContext session,
    int? selectedVehicleId,
    AssistantPageContext? pageContext,
  ) {
    if (selectedVehicleId == null ||
        pageContext?.vehicleId != selectedVehicleId) {
      return session;
    }
    final selectedQuery =
        session.lastVehicleQuery?.vehicle.vehicleId == selectedVehicleId
        ? session.lastVehicleQuery
        : null;
    return AssistantSessionContext(
      lastBusinessType: AssistantBusinessType.vehicleAnnualRepair,
      lastVehicleQuery: selectedQuery,
    );
  }

  void _consumePageVehicleSelection(
    int? selectedVehicleId,
    AttendanceAction action,
  ) {
    if (selectedVehicleId != null &&
        action != AttendanceAction.unsupported &&
        _pendingPageVehicleSelection == selectedVehicleId) {
      _pendingPageVehicleSelection = null;
    }
  }

  AttendanceIntent? _parseExplicitLocalFollowUp(
    String text,
    AssistantSessionContext session,
  ) {
    final normalized = text.replaceAll(RegExp(r'[。！!？?]+$'), '').trim();
    if (session.lastBusinessType != AssistantBusinessType.attendance) {
      if (RegExp(r'^(?:请)?(?:重新|再)查(?:一下|一遍|一次)?$').hasMatch(normalized)) {
        return const AttendanceIntent(action: AttendanceAction.refresh);
      }
      if (RegExp(r'^(?:请)?查去年(?:的)?(?:维修|费用|排名)?$').hasMatch(normalized)) {
        return const AttendanceIntent(
          action: AttendanceAction.changeYear,
          yearReference: YearReference.previous,
        );
      }
      return null;
    }
    if (session.lastQuery == null) return null;
    if (RegExp(r'^(?:请)?(?:重新|再)查(?:一下|一遍|一次)?$').hasMatch(normalized)) {
      return const AttendanceIntent(action: AttendanceAction.refresh);
    }
    if (RegExp(r'^(?:请)?查去年(?:的)?(?:考勤)?$').hasMatch(normalized)) {
      return const AttendanceIntent(
        action: AttendanceAction.changeYear,
        yearReference: YearReference.previous,
        month: null,
      );
    }
    final person = RegExp(
      r'^那([\p{L}\p{N}·_-]{1,24})呢$',
      unicode: true,
    ).firstMatch(normalized)?.group(1);
    if (person != null) {
      return AttendanceIntent(
        action: AttendanceAction.changeEmployee,
        employeeText: person,
        yearReference: YearReference.inherit,
      );
    }
    return null;
  }

  bool _isSingleEntityReply(String text) =>
      RegExp(r'^[\p{L}\p{N}·_-]{1,30}$', unicode: true).hasMatch(text) &&
      !_isMonthReply(text) &&
      !RegExp(r'(?:查|考勤|出勤|加班|工资|年份|月份|帮我|请问|维修|费用|排名|全车|所有车辆|今年|去年|本年|本年度)')
          .hasMatch(text);

  bool _isMonthReply(String text) =>
      RegExp(r'^(?:本月|上月|\d{4}年?\d{1,2}月?|\d{1,2}月)$').hasMatch(text.trim());

  String _resolveMonthReply(String text, int? requestedYear) {
    final normalized = text.trim();
    final now = _clock();
    if (normalized == '本月') {
      return _formatMonth(requestedYear ?? now.year, now.month);
    }
    if (normalized == '上月') {
      final previous = DateTime(now.year, now.month - 1);
      return _formatMonth(requestedYear ?? previous.year, previous.month);
    }
    final match = RegExp(r'^(?:(\d{4})年?)?(\d{1,2})月?$')
        .firstMatch(normalized)!;
    final month = int.parse(match.group(2)!);
    final inheritedYear = _state.session.lastQuery == null
        ? null
        : int.tryParse(_state.session.lastQuery!.yearMonth.substring(0, 4));
    final year =
        int.tryParse(match.group(1) ?? '') ??
        requestedYear ??
        inheritedYear ??
        now.year;
    return _formatMonth(year, month);
  }

  String _formatMonth(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  bool _validYearMonth(String value) =>
      RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value);

  AssistantAnswer _copyAnswer(AssistantAnswer answer, {String? explanation}) =>
      AssistantAnswer(
        text: answer.text,
        employeeLabel: answer.employeeLabel,
        yearMonth: answer.yearMonth,
        queriedAt: answer.queriedAt,
        completeness: answer.completeness,
        yearMonthSource: answer.yearMonthSource,
        attendanceDays: answer.attendanceDays,
        leaveAndRestDays: answer.leaveAndRestDays,
        overtimeMinutes: answer.overtimeMinutes,
        groupLabels: answer.groupLabels,
        groupIds: answer.groupIds,
        localDetails: answer.localDetails,
        sourceRule: answer.sourceRule,
        sourcePage: answer.sourcePage,
        explanation: explanation ?? answer.explanation,
        error: answer.error,
        vehicleSummary: answer.vehicleSummary,
        vehicleRanking: answer.vehicleRanking,
        vehicleExpenseAnalysis: answer.vehicleExpenseAnalysis,
        businessResult: answer.businessResult,
      );
}

extension on ResolvedIntent {
  ResolvedIntent copyWith({
    String? yearMonth,
    int? requestedYear,
    String? employeeText,
    int? employeeId,
    bool clearEmployeeId = false,
    String? vehicleText,
    int? vehicleId,
    bool clearVehicleId = false,
  }) => ResolvedIntent(
    action: action,
    yearMonth: yearMonth ?? this.yearMonth,
    yearMonthSource: yearMonth == null
        ? yearMonthSource
        : AssistantFieldSource.input,
    requestedYear: requestedYear ?? this.requestedYear,
    employeeText: employeeText ?? this.employeeText,
    employeeId: clearEmployeeId ? null : employeeId ?? this.employeeId,
    groupId: groupId,
    clarification: clarification,
    error: error,
    businessType: businessType,
    vehicleText: vehicleText ?? this.vehicleText,
    vehicleId: clearVehicleId ? null : vehicleId ?? this.vehicleId,
    allVehicles: allVehicles,
  );
}

extension on ResolvedVehicleRankingQuery {
  ResolvedVehicleRankingQuery copyWith({
    String? resultRef,
    String? cursor,
    bool clearResultRef = false,
    bool clearCursor = false,
  }) => ResolvedVehicleRankingQuery(
    year: year,
    limit: limit,
    resultRef: clearResultRef ? null : resultRef ?? this.resultRef,
    cursor: clearCursor ? null : cursor ?? this.cursor,
  );
}
