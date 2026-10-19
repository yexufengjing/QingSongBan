import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/application/assistant_controller.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 17, 12);

  test(
    'free text uses Provider; explicit follow-ups reuse local conditions',
    () async {
      final provider = _FakeProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '张三',
          month: 9,
          yearReference: YearReference.current,
        ),
      ]);
      final attendance = _FakeAttendancePort();
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        clock: () => fixedNow,
      );

      await controller.submit('帮我看看张三九月份怎么样');
      await controller.submit('查去年');
      await controller.submit('查去年');
      await controller.submit('那李四呢');
      await controller.submit('重新查一下');

      expect(provider.parseTexts, ['帮我看看张三九月份怎么样']);
      expect(attendance.readQueries.map((query) => query.yearMonth), [
        '2026-09',
        '2025-09',
        '2025-09',
        '2025-09',
        '2025-09',
      ]);
      expect(attendance.readQueries[3].employee.label, '李四');
      expect(attendance.readQueries[3].groupId, isNull);
      expect(
        controller.state.messages.last.metrics!.resolutionPath,
        AssistantResolutionPath.localFollowUp,
      );
      expect(controller.state.messages.last.metrics!.parseCalls, 0);

      controller.updatePageContext(
        const AssistantPageContext(
          module: 'attendance',
          page: 'monthly-table',
          yearMonth: '2024-03',
        ),
      );
      expect(controller.state.session.lastQuery!.yearMonth, '2025-09');
    },
  );

  test('business session keeps historical month, inherits subject, and prefers explicit subject to page id', () async {
    final provider = _FakeProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryBusiness,
        businessType: AssistantBusinessType.payroll,
        businessQuestion: '查询工资',
        businessSubject: '甲员工',
        year: 2025,
        month: 9,
        yearReference: YearReference.explicit,
      ),
      const AttendanceIntent(
        action: AttendanceAction.queryBusiness,
        businessType: AssistantBusinessType.payroll,
        businessQuestion: '那乙呢',
        businessSubject: '乙员工',
        businessOperation: 'inherit',
      ),
      const AttendanceIntent(
        action: AttendanceAction.queryBusiness,
        businessType: AssistantBusinessType.payroll,
        businessQuestion: '那上个月呢',
        month: 8,
        yearReference: YearReference.inherit,
        businessOperation: 'inherit',
      ),
      const AttendanceIntent(
        action: AttendanceAction.queryBusiness,
        businessType: AssistantBusinessType.payroll,
        businessQuestion: '查丙员工工资',
        businessSubject: '丙员工',
      ),
      const AttendanceIntent(
        action: AttendanceAction.queryBusiness,
        businessType: AssistantBusinessType.payroll,
        businessQuestion: '查当前页面工资',
      ),
    ]);
    final reader = _FakeBusinessReader();
    final controller = AssistantController(
      provider: provider,
      attendance: _FakeAttendancePort(),
      businessReader: reader,
      clock: () => fixedNow,
    );
    controller.updatePageContext(
      const AssistantPageContext(
        module: 'payroll',
        page: 'payroll-detail',
        yearMonth: '2026-10',
        employeeId: 777,
      ),
    );

    await controller.submit('查甲员工2025年9月工资');
    await controller.submit('那乙呢');
    await controller.submit('那上个月呢');
    await controller.submit('查丙员工工资');
    await controller.submit('查当前页面工资');

    expect(
      reader.queries.map(
        (query) => (query.yearMonth, query.subject, query.employeeId),
      ),
      [
        ('2025-09', '甲员工', null),
        ('2025-09', '乙员工', null),
        ('2025-08', '乙员工', null),
        ('2025-08', '丙员工', null),
        ('2025-08', null, 777),
      ],
    );
    expect(provider.parseTexts, [
      '查甲员工2025年9月工资',
      '那乙呢',
      '那上个月呢',
      '查丙员工工资',
      '查当前页面工资',
    ]);
    expect(
      provider.requests.map((request) => request.previousBusinessYearMonth),
      [null, '2025-09', '2025-09', '2025-08', '2025-08'],
    );
  });

  test(
    'not-in-roster query preserves validated conditions for year follow-up',
    () async {
      final provider = _FakeProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '张三',
          month: 9,
          yearReference: YearReference.current,
        ),
      ]);
      final attendance = _FakeAttendancePort()
        ..firstReadStatus = AttendanceReadStatus.notInRoster;
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        clock: () => fixedNow,
      );

      await controller.submit('查张三9月考勤');
      final noRosterAnswer = controller.state.messages.last.answer!;
      expect(noRosterAnswer.text, contains('不在 2026 年 09 月'));
      expect(noRosterAnswer.attendanceDays, isNull);
      expect(noRosterAnswer.leaveAndRestDays, isNull);
      expect(noRosterAnswer.overtimeMinutes, isNull);
      expect(controller.state.session.lastQuery!.yearMonth, '2026-09');

      await controller.submit('查去年');

      expect(provider.parseTexts, ['查张三9月考勤']);
      expect(attendance.readQueries.map((query) => query.yearMonth), [
        '2026-09',
        '2025-09',
      ]);
      expect(
        attendance.readQueries[1].employee.employeeId,
        attendance.readQueries[0].employee.employeeId,
      );
      expect(attendance.readQueries[1].employee.label, '张三');
    },
  );

  test(
    'technical read failure does not replace last successful conditions',
    () async {
      final provider = _FakeProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '张三',
          year: 2026,
          month: 9,
          yearReference: YearReference.explicit,
        ),
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '李四',
          year: 2025,
          month: 8,
          yearReference: YearReference.explicit,
        ),
      ]);
      final attendance = _FakeAttendancePort()..readErrorOnCall = 2;
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        clock: () => fixedNow,
      );

      await controller.submit('查张三2026年9月考勤');
      final lastSuccessfulEmployeeId =
          controller.state.session.lastQuery!.employee.employeeId;
      await controller.submit('查李四2025年8月考勤');
      expect(controller.state.messages.last.error, AssistantErrorCode.unknown);
      expect(
        controller.state.session.lastQuery!.employee.employeeId,
        lastSuccessfulEmployeeId,
      );
      expect(controller.state.session.lastQuery!.yearMonth, '2026-09');

      await controller.submit('查去年');

      expect(provider.parseTexts, ['查张三2026年9月考勤', '查李四2025年8月考勤']);
      expect(attendance.readQueries.map((query) => query.yearMonth), [
        '2026-09',
        '2025-08',
        '2025-09',
      ]);
      expect(
        attendance.readQueries.last.employee.employeeId,
        lastSuccessfulEmployeeId,
      );
      expect(attendance.readQueries.last.employee.label, '张三');
    },
  );

  test('month clarification keeps an explicitly requested year', () async {
    final provider = _FakeProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '张三',
        year: 2023,
        yearReference: YearReference.explicit,
      ),
    ]);
    final attendance = _FakeAttendancePort();
    final controller = AssistantController(
      provider: provider,
      attendance: attendance,
      clock: () => fixedNow,
    );

    await controller.submit('查张三2023年考勤');
    expect(controller.state.messages.last.text, '查哪个月？');
    await controller.submit('9月');

    expect(provider.parseTexts, hasLength(1));
    expect(attendance.readQueries.single.yearMonth, '2023-09');
    expect(controller.state.messages.last.answer!.yearMonth, '2023-09');
  });

  test(
    'missing employee asks only for a name and keeps parsed month locally',
    () async {
      final provider = _FakeProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          year: 2025,
          month: 7,
          yearReference: YearReference.explicit,
        ),
      ]);
      final attendance = _FakeAttendancePort();
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        clock: () => fixedNow,
      );

      await controller.submit('查2025年7月考勤');
      expect(controller.state.messages.last.text, '要查哪位人员？');
      expect(attendance.readQueries, isEmpty);

      await controller.submit('张三');

      expect(provider.parseTexts, ['查2025年7月考勤']);
      expect(attendance.readQueries, hasLength(1));
      expect(attendance.readQueries.single.employee.label, '张三');
      expect(attendance.readQueries.single.yearMonth, '2025-07');
    },
  );

  test('a month reply is not treated as a person, and a new full question replaces pending context', () async {
    final provider = _FakeProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '张三',
        year: 2023,
        yearReference: YearReference.explicit,
      ),
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '李四',
        year: 2024,
        month: 8,
        yearReference: YearReference.explicit,
      ),
    ]);
    final attendance = _FakeAttendancePort();
    final controller = AssistantController(
      provider: provider,
      attendance: attendance,
      clock: () => fixedNow,
    );

    await controller.submit('查张三2023年考勤');
    await controller.submit('帮我查李四2024年8月的情况');

    expect(provider.parseTexts, hasLength(2));
    expect(attendance.readQueries.single.employee.label, '李四');
    expect(attendance.readQueries.single.yearMonth, '2024-08');
  });

  test(
    'candidate click continues directly and old task candidates are rejected',
    () async {
      final provider = _FakeProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '王五',
          year: 2026,
          month: 9,
          yearReference: YearReference.explicit,
        ),
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '赵六',
          year: 2026,
          month: 9,
          yearReference: YearReference.explicit,
        ),
      ]);
      final attendance = _FakeAttendancePort()..returnCandidates = true;
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        clock: () => fixedNow,
      );

      await controller.submit('查王五2026年9月考勤');
      final oldCandidate = controller.state.messages.last.candidates.first;
      await controller.submit('查赵六2026年9月考勤');
      final currentCandidates = controller.state.messages.last.candidates;
      await controller.selectCandidate(oldCandidate.candidateRef);
      expect(attendance.readQueries, isEmpty);

      await controller.selectCandidate(currentCandidates.last.candidateRef);
      expect(provider.parseTexts, hasLength(2));
      expect(attendance.readQueries, hasLength(1));
      expect(attendance.readQueries.single.employee.label, '赵六');
      expect(controller.state.messages.last.answer, isNotNull);
    },
  );

  test('clearSession invalidates the active candidate choice', () async {
    final provider = _FakeProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '王五',
        year: 2026,
        month: 9,
        yearReference: YearReference.explicit,
      ),
    ]);
    final attendance = _FakeAttendancePort()..returnCandidates = true;
    final controller = AssistantController(
      provider: provider,
      attendance: attendance,
      clock: () => fixedNow,
    );

    await controller.submit('查王五2026年9月考勤');
    final candidate = controller.state.messages.last.candidates.first;
    controller.clearSession();
    await controller.selectCandidate(candidate.candidateRef);

    expect(attendance.readQueries, isEmpty);
    expect(controller.state.session.lastQuery, isNull);
  });

  test('unsupported intent never reuses an earlier attendance query', () async {
    final provider = _FakeProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '张三',
        year: 2026,
        month: 9,
        yearReference: YearReference.explicit,
      ),
      const AttendanceIntent(action: AttendanceAction.unsupported),
    ]);
    final attendance = _FakeAttendancePort();
    final controller = AssistantController(
      provider: provider,
      attendance: attendance,
      clock: () => fixedNow,
    );

    await controller.submit('查张三2026年9月考勤');
    await controller.submit('帮我算下今年工资');

    expect(attendance.readQueries, hasLength(1));
    expect(
      controller.state.messages.last.error,
      AssistantErrorCode.unsupported,
    );
    expect(
      controller.state.messages.last.text,
      '助手支持查询和分析，修改请到业务页面办理。',
    );
  });

  test('Provider error code maps to a controlled message and no old answer is overwritten', () async {
    final provider = _FakeProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '张三',
        year: 2026,
        month: 9,
        yearReference: YearReference.explicit,
      ),
    ])..throwParseError = AssistantErrorCode.unauthorized;
    final attendance = _FakeAttendancePort();
    final controller = AssistantController(
      provider: provider,
      attendance: attendance,
      clock: () => fixedNow,
    );

    await controller.submit('查询考勤');

    expect(
      controller.state.messages.last.error,
      AssistantErrorCode.unauthorized,
    );
    expect(controller.state.messages.last.text, 'API Key 无效，请检查助手设置。');
    expect(attendance.readQueries, isEmpty);
  });

  test('explanation sends only the four-field summary and preserves answer on failure', () async {
    var now = fixedNow;
    final provider = _UsageFakeProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '张三',
        year: 2026,
        month: 9,
        yearReference: YearReference.explicit,
      ),
    ])..throwExplanation = true;
    provider.onExplanation = () =>
        now = now.add(const Duration(milliseconds: 1250));
    final attendance = _FakeAttendancePort();
    final controller = AssistantController(
      provider: provider,
      attendance: attendance,
      clock: () => now,
    );

    await controller.submit('查张三2026年9月考勤');
    final resultMessageId = controller.state.messages.last.id;
    final original = controller.state.messages.last.answer!;
    await controller.explainAnswer('$resultMessageId');

    expect(provider.explanationSummary!.toJson(), {
      'yearMonth': '2026-09',
      'attendanceDays': 1.5,
      'leaveAndRestDays': 0.5,
      'overtimeMinutes': 90,
    });
    final after = controller.state.messages.last.answer!;
    expect(after.attendanceDays, original.attendanceDays);
    expect(after.text, original.text);
    expect(after.explanation, '文字解释暂不可用');
    final metrics = controller.state.messages.last.metrics!;
    expect(metrics.explanationCalls, 1);
    expect(metrics.providerCalls, 2);
    expect(metrics.inputTokens, 13);
    expect(metrics.outputTokens, 4);
    expect(metrics.providerDuration, const Duration(milliseconds: 850));
    expect(metrics.elapsed, const Duration(milliseconds: 1250));
    expect(controller.state.phase, AssistantTurnPhase.idle);
  });

  test(
    'successful explanations accumulate elapsed time and known provider usage',
    () async {
      var now = fixedNow;
      final provider = _UsageFakeProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '张三',
          year: 2026,
          month: 9,
          yearReference: YearReference.explicit,
        ),
      ]);
      provider.onExplanation = () =>
          now = now.add(const Duration(milliseconds: 800));
      final controller = AssistantController(
        provider: provider,
        attendance: _FakeAttendancePort(),
        clock: () => now,
      );

      await controller.submit('查张三2026年9月考勤');
      final messageId = controller.state.messages.last.id;
      expect(controller.state.messages.last.metrics!.elapsed, Duration.zero);

      await controller.explainAnswer('$messageId');
      await controller.explainAnswer('$messageId');

      final message = controller.state.messages.last;
      expect(message.answer!.explanation, '解释');
      expect(message.metrics!.explanationCalls, 2);
      expect(message.metrics!.providerCalls, 3);
      expect(message.metrics!.inputTokens, 15);
      expect(message.metrics!.outputTokens, 5);
      expect(
        message.metrics!.providerDuration,
        const Duration(milliseconds: 1550),
      );
      expect(message.metrics!.elapsed, const Duration(milliseconds: 1600));
    },
  );

  test(
    'cancelled late parse cannot update state and transport callback fires',
    () async {
      final delayed = Completer<AttendanceIntent>();
      final provider = _FakeProvider([])..parseCompleter = delayed;
      final attendance = _FakeAttendancePort();
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        clock: () => fixedNow,
      );
      var aborted = false;

      final submit = controller.submit('一个没有本地明确规则的自由请求');
      await Future<void>.delayed(Duration.zero);
      controller.state.pendingRequest!.addCancelHandler(() => aborted = true);
      controller.cancelCurrentTask();
      delayed.complete(
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '张三',
          year: 2026,
          month: 9,
          yearReference: YearReference.explicit,
        ),
      );
      await submit;

      expect(aborted, isTrue);
      expect(controller.state.pendingRequest, isNull);
      expect(
        controller.state.messages.where((message) => message.answer != null),
        isEmpty,
      );
      expect(attendance.readQueries, isEmpty);
    },
  );

  test(
    'a new task succeeds after cancellation and late old response is ignored',
    () async {
      final delayedOld = Completer<AttendanceIntent>();
      final provider = _FakeProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '李四',
          year: 2026,
          month: 9,
          yearReference: YearReference.explicit,
        ),
      ])..parseCompleter = delayedOld;
      final attendance = _FakeAttendancePort();
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        clock: () => fixedNow,
      );

      final oldSubmit = controller.submit('旧任务自由问句');
      await Future<void>.delayed(Duration.zero);
      controller.cancelCurrentTask();
      await controller.submit('查李四2026年9月考勤');
      delayedOld.complete(
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '张三',
          year: 2025,
          month: 8,
          yearReference: YearReference.explicit,
        ),
      );
      await oldSubmit;

      expect(provider.parseTexts, ['旧任务自由问句', '查李四2026年9月考勤']);
      expect(attendance.readQueries, hasLength(1));
      expect(attendance.readQueries.single.employee.label, '李四');
      expect(attendance.readQueries.single.yearMonth, '2026-09');
      expect(controller.state.session.lastQuery!.employee.label, '李四');
    },
  );

  test(
    'duplicate submit is ignored while the first parse is pending',
    () async {
      final delayed = Completer<AttendanceIntent>();
      final provider = _FakeProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '张三',
          year: 2026,
          month: 9,
          yearReference: YearReference.explicit,
        ),
      ])..parseCompleter = delayed;
      final attendance = _FakeAttendancePort();
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        clock: () => fixedNow,
      );

      final first = controller.submit('查张三2026年9月考勤');
      await Future<void>.delayed(Duration.zero);
      await controller.submit('查张三2026年9月考勤');
      delayed.complete(
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '张三',
          year: 2026,
          month: 9,
          yearReference: YearReference.explicit,
        ),
      );
      await first;

      expect(provider.parseTexts, ['查张三2026年9月考勤']);
      expect(attendance.readQueries, hasLength(1));
    },
  );

  test('candidate double click resolves and reads only once', () async {
    final provider = _FakeProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '王五',
        year: 2026,
        month: 9,
        yearReference: YearReference.explicit,
      ),
    ]);
    final attendance = _FakeAttendancePort()..returnCandidates = true;
    final controller = AssistantController(
      provider: provider,
      attendance: attendance,
      clock: () => fixedNow,
    );
    await controller.submit('查王五2026年9月考勤');
    final candidate = controller.state.messages.last.candidates.first;
    final delayedResolution = Completer<EmployeeResolution>();
    attendance.candidateResolveCompleter = delayedResolution;

    final first = controller.selectCandidate(candidate.candidateRef);
    await Future<void>.delayed(Duration.zero);
    await controller.selectCandidate(candidate.candidateRef);
    delayedResolution.complete(
      const EmployeeResolution(
        status: EmployeeResolutionStatus.unique,
        employee: ResolvedEmployee(employeeId: 101, label: '王五'),
      ),
    );
    await first;

    expect(attendance.candidateResolveCalls, 1);
    expect(attendance.readQueries, hasLength(1));
  });

  test('refreshing an older result rereads its own query and current local snapshot', () async {
    final provider = _FakeProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '张三',
        year: 2026,
        month: 9,
        yearReference: YearReference.explicit,
      ),
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '李四',
        year: 2025,
        month: 8,
        yearReference: YearReference.explicit,
      ),
    ]);
    final attendance = _FakeAttendancePort()
      ..readAttendanceDays = [1.5, 2.5, 3.5];
    final controller = AssistantController(
      provider: provider,
      attendance: attendance,
      clock: () => fixedNow,
    );

    await controller.submit('查张三2026年9月考勤');
    final originalResultId = controller.state.messages.last.id;
    await controller.submit('查李四2025年8月考勤');
    await controller.refreshResult('$originalResultId');

    expect(attendance.readQueries.map((query) => query.employee.label), [
      '张三',
      '李四',
      '张三',
    ]);
    expect(attendance.readQueries.map((query) => query.yearMonth), [
      '2026-09',
      '2025-08',
      '2026-09',
    ]);
    expect(controller.state.messages.last.answer!.attendanceDays, 3.5);
  });
}

class _FakeProvider implements AIProvider {
  _FakeProvider(this.intents);

  final List<AttendanceIntent> intents;
  final parseTexts = <String>[];
  final requests = <IntentRequest>[];
  Completer<AttendanceIntent>? parseCompleter;
  AssistantErrorCode? throwParseError;
  bool throwExplanation = false;
  AttendanceOutboundSummary? explanationSummary;
  void Function()? onExplanation;

  @override
  Future<AttendanceIntent> parseIntent(
    IntentRequest request,
    RequestToken token,
  ) async {
    parseTexts.add(request.text);
    requests.add(request);
    if (parseCompleter != null) {
      final delayed = parseCompleter!;
      parseCompleter = null;
      return delayed.future;
    }
    if (throwParseError != null) {
      throw AssistantProviderException(throwParseError!);
    }
    return intents.removeAt(0);
  }

  @override
  Future<SummaryExplanation> explainSummary(
    AttendanceOutboundSummary summary,
    RequestToken token,
  ) async {
    explanationSummary = summary;
    onExplanation?.call();
    if (throwExplanation) {
      throw const AssistantProviderException(AssistantErrorCode.network);
    }
    return const SummaryExplanation(text: '解释');
  }

  @override
  Future<ConnectionCheck> checkConnection(RequestToken token) async =>
      const ConnectionCheck(success: true);
}

class _FakeBusinessReader implements AssistantBusinessReadPort {
  final queries = <AssistantBusinessQuery>[];

  @override
  Future<AssistantBusinessReadResult> read(AssistantBusinessQuery query) async {
    queries.add(query);
    return AssistantBusinessReadResult(
      domain: query.domain,
      title: query.subject ?? '工资',
      summary: '测试结果',
      queriedAt: query.now ?? DateTime(2026, 10, 17),
      sourceRule: '测试规则',
      sourcePage: '/reports/payroll',
    );
  }
}

class _UsageFakeProvider extends _FakeProvider implements AIProviderUsage {
  _UsageFakeProvider(super.intents);

  final Map<int, _FakeUsageTotals> _usageByRequest = {};

  @override
  AIProviderUsageSnapshot get usageSnapshot {
    final usages = _usageByRequest.values;
    return AIProviderUsageSnapshot(
      parseCalls: usages.fold<int>(0, (sum, usage) => sum + usage.parseCalls),
      explanationCalls: usages.fold<int>(
        0,
        (sum, usage) => sum + usage.explanationCalls,
      ),
      connectionChecks: 0,
      inputTokens: usages.fold<int>(0, (sum, usage) => sum + usage.inputTokens),
      outputTokens: usages.fold<int>(
        0,
        (sum, usage) => sum + usage.outputTokens,
      ),
      totalDuration: usages.fold<Duration>(
        Duration.zero,
        (sum, usage) => sum + usage.duration,
      ),
    );
  }

  @override
  AIProviderUsageSnapshot usageForRequest(int requestId) =>
      (_usageByRequest[requestId] ?? _FakeUsageTotals()).snapshot;

  @override
  Future<AttendanceIntent> parseIntent(
    IntentRequest request,
    RequestToken token,
  ) async {
    final intent = await super.parseIntent(request, token);
    _record(
      token.id,
      parseCalls: 1,
      inputTokens: 11,
      outputTokens: 3,
      duration: const Duration(milliseconds: 150),
    );
    return intent;
  }

  @override
  Future<SummaryExplanation> explainSummary(
    AttendanceOutboundSummary summary,
    RequestToken token,
  ) {
    _record(
      token.id,
      explanationCalls: 1,
      inputTokens: 2,
      outputTokens: 1,
      duration: const Duration(milliseconds: 700),
    );
    return super.explainSummary(summary, token);
  }

  void _record(
    int requestId, {
    int parseCalls = 0,
    int explanationCalls = 0,
    required int inputTokens,
    required int outputTokens,
    required Duration duration,
  }) {
    final usage = _usageByRequest.putIfAbsent(requestId, _FakeUsageTotals.new);
    usage
      ..parseCalls += parseCalls
      ..explanationCalls += explanationCalls
      ..inputTokens += inputTokens
      ..outputTokens += outputTokens
      ..duration += duration;
  }
}

class _FakeUsageTotals {
  int parseCalls = 0;
  int explanationCalls = 0;
  int inputTokens = 0;
  int outputTokens = 0;
  Duration duration = Duration.zero;

  AIProviderUsageSnapshot get snapshot => AIProviderUsageSnapshot(
    parseCalls: parseCalls,
    explanationCalls: explanationCalls,
    connectionChecks: 0,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    totalDuration: duration,
  );
}

class _FakeAttendancePort implements AttendanceReadPort {
  final readQueries = <ResolvedAttendanceQuery>[];
  bool returnCandidates = false;
  Completer<EmployeeResolution>? candidateResolveCompleter;
  var candidateResolveCalls = 0;
  List<double>? readAttendanceDays;
  AttendanceReadStatus? firstReadStatus;
  int? readErrorOnCall;
  var _nextEmployeeId = 10;
  final Map<int, ResolvedEmployee> _employees = {};

  @override
  Future<EmployeeResolution> resolveEmployee(EmployeeSelector selector) async {
    if (returnCandidates) {
      return EmployeeResolution(
        status: EmployeeResolutionStatus.candidates,
        candidates: [
          EmployeeCandidate(
            candidateRef: 'candidate-${_nextEmployeeId++}',
            employeeId: 101,
            label: selector.employeeText ?? '王五',
          ),
          EmployeeCandidate(
            candidateRef: 'candidate-${_nextEmployeeId++}',
            employeeId: 102,
            label: selector.employeeText ?? '王五',
          ),
        ],
      );
    }
    final employee = selector.employeeId == null
        ? ResolvedEmployee(
            employeeId: _nextEmployeeId++,
            label: selector.employeeText!,
          )
        : ResolvedEmployee(
            employeeId: selector.employeeId!,
            label: selector.existingEmployee?.label.isNotEmpty == true
                ? selector.existingEmployee!.label
                : '张三',
          );
    _employees[employee.employeeId] = employee;
    return EmployeeResolution(
      status: EmployeeResolutionStatus.unique,
      employee: employee,
    );
  }

  @override
  Future<EmployeeResolution> resolveCandidate(String candidateRef) async {
    candidateResolveCalls++;
    final delayed = candidateResolveCompleter;
    if (delayed != null) return delayed.future;
    return EmployeeResolution(
      status: EmployeeResolutionStatus.unique,
      employee: ResolvedEmployee(employeeId: 101, label: '赵六'),
    );
  }

  @override
  Future<AttendanceReadResult> readMonth(ResolvedAttendanceQuery query) async {
    readQueries.add(query);
    if (readErrorOnCall == readQueries.length) {
      throw StateError('simulated local read failure');
    }
    final status = readQueries.length == 1
        ? firstReadStatus ?? AttendanceReadStatus.success
        : AttendanceReadStatus.success;
    return AttendanceReadResult(
      status: status,
      employeeLabel: query.employee.label,
      yearMonth: query.yearMonth,
      queriedAt: DateTime(2026, 10, 17),
      completeness: AttendanceCompleteness.notEvaluated,
      attendanceDays: status != AttendanceReadStatus.success
          ? null
          : readAttendanceDays == null
          ? 1.5
          : readAttendanceDays![readQueries.length - 1],
      leaveAndRestDays: status == AttendanceReadStatus.success ? 0.5 : null,
      overtimeMinutes: status == AttendanceReadStatus.success ? 90 : null,
      groupLabels: const ['测试组'],
    );
  }
}
