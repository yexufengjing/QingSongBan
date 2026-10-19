import 'dart:async';
import 'dart:convert';

import '../domain/assistant_models.dart';

typedef AssistantAgentClock = DateTime Function();
typedef AssistantAgentProgress = void Function(String label);
typedef AssistantAgentPartial = void Function(AssistantAgentRunResult result);

/// Executes only the fixed, read-only vehicle expense tool allowlist.
class AssistantVehicleExpenseRunner {
  AssistantVehicleExpenseRunner({
    required VehicleExpenseAgentProvider provider,
    required VehicleExpenseReadPort reader,
    AssistantAgentClock? clock,
  }) : _provider = provider,
       _reader = reader,
       _clock = clock ?? DateTime.now;

  static const maxModelRequests = 6;
  static const maxBusinessTools = 8;
  static const maxElapsed = Duration(seconds: 120);

  final VehicleExpenseAgentProvider _provider;
  final VehicleExpenseReadPort _reader;
  final AssistantAgentClock _clock;

  Future<AssistantAgentRunResult> run({
    required String utterance,
    required int vehicleId,
    required AssistantAgentPeriod period,
    required VehicleExpenseCategoryScope scope,
    String? yearMonth,
    required RequestToken token,
    DateTime? taskStartedAt,
    int priorModelRequests = 1,
    AssistantAgentProgress? onProgress,
    AssistantAgentPartial? onPartial,
  }) async {
    final startedAt = taskStartedAt ?? _clock();
    final effectiveYearMonth =
        yearMonth ??
        (period == AssistantAgentPeriod.previousMonth
            ? _previousMonthOfToday(_clock())
            : null);
    final messages = <AssistantAgentMessage>[
      AssistantAgentMessage(
        role: 'system',
        content:
            'You analyze one locally resolved vehicle using read-only aggregate tools. '
            'The selected vehicle and its identity are private local context; never request '
            'or invent IDs, names, plate numbers, records, remarks, or symptoms. The app '
            'has bound the current vehicle locally. Choose tools based on the user request '
            'and results; compare periods or inspect drivers only when useful, and stop when '
            'the evidence is sufficient. Use a 30-day rolling period by default; monthly fuel '
            'is returned separately and must not be described as an exact rolling-period total. '
            'Do not claim missing records are zero spending. Do not infer abnormal use or cause '
            'from amount differences alone. Final text should be brief and qualitative; all '
            'numbers and dates are rendered from local evidence by the app. Never state '
            'numeric facts in your final text. If the user is correcting a previous expense '
            'analysis, use the specified category and period in tool calls. The locally selected '
            'vehicle is available. User-requested category: ${scope.name}. '
            'App-selected period: ${period.name}. Explicit month: ${effectiveYearMonth ?? 'none'}.',
      ),
      AssistantAgentMessage(role: 'user', content: utterance),
    ];
    final periods = <VehicleExpensePeriodResult>[];
    final evidence = <VehicleExpenseEvidence>[];
    final peerComparisons = <VehicleExpensePeerResult>[];
    final executedTools = <AssistantAgentToolName>[];
    var toolCalls = 0;
    var modelCalls = priorModelRequests;
    String? finalText;
    AssistantErrorCode? failure;
    var timedOut = false;
    final remaining = maxElapsed - _clock().difference(startedAt);
    AssistantAgentRunResult snapshot({bool stopped = false}) =>
        AssistantAgentRunResult(
          periods: List.unmodifiable(periods),
          evidence: List.unmodifiable(evidence),
          toolCalls: toolCalls,
          summaryText: finalText,
          stopped: stopped,
          failure: failure,
          peerComparisons: List.unmodifiable(peerComparisons),
          executedTools: List.unmodifiable(executedTools),
        );
    if (remaining <= Duration.zero) {
      failure = AssistantErrorCode.timeout;
      return snapshot();
    }
    final deadline = Timer(remaining, () {
      timedOut = true;
      token.cancel();
    });

    try {
      while (modelCalls < maxModelRequests &&
          toolCalls <= maxBusinessTools &&
          _clock().difference(startedAt) < maxElapsed) {
        if (token.isCancelled) {
          return snapshot(stopped: true);
        }
        modelCalls++;
        onProgress?.call('正在分析需求');
        final turn = await _provider
            .completeAgentTurn(messages, token)
            .timeout(_remaining(startedAt));
        if (token.isCancelled) {
          failure = timedOut
              ? AssistantErrorCode.timeout
              : AssistantErrorCode.cancelled;
          return snapshot(stopped: !timedOut);
        }
        if (turn.toolCalls.isEmpty) {
          if (periods.isEmpty) {
            messages
              ..add(
                AssistantAgentMessage(role: 'assistant', content: turn.text),
              )
              ..add(
                const AssistantAgentMessage(
                  role: 'user',
                  content: 'Use a read-only expense summary tool before answering. Do not guess whether this vehicle spent more.',
                ),
              );
            continue;
          }
          finalText = _qualitativeOnly(turn.text);
          return snapshot();
        }
        messages.add(
          AssistantAgentMessage(
            role: 'assistant',
            content: turn.text,
            toolCalls: turn.toolCalls,
          ),
        );
        for (final call in turn.toolCalls) {
          if (toolCalls >= maxBusinessTools) {
            failure = AssistantErrorCode.unsupported;
            return snapshot();
          }
          if (token.isCancelled) return snapshot(stopped: true);
          toolCalls++;
          executedTools.add(call.name);
          final result = await _executeTool(
            call,
            vehicleId: vehicleId,
            defaultPeriod: period,
            defaultScope: scope,
            defaultYearMonth: effectiveYearMonth,
            periods: periods,
            evidence: evidence,
            peerComparisons: peerComparisons,
            onProgress: onProgress,
          ).timeout(_remaining(startedAt));
          messages.add(
            AssistantAgentMessage(
              role: 'tool',
              content: jsonEncode(result),
              toolCallId: call.id,
            ),
          );
          onPartial?.call(snapshot());
          if (token.isCancelled) {
            failure = timedOut
                ? AssistantErrorCode.timeout
                : AssistantErrorCode.cancelled;
            return snapshot(stopped: !timedOut);
          }
          if (toolCalls >= maxBusinessTools && modelCalls >= maxModelRequests) {
            failure = AssistantErrorCode.unsupported;
            return snapshot();
          }
        }
      }
      failure = _clock().difference(startedAt) >= maxElapsed
          ? AssistantErrorCode.timeout
          : AssistantErrorCode.unsupported;
      return snapshot();
    } on AssistantProviderException catch (error) {
      failure = timedOut
          ? AssistantErrorCode.timeout
          : token.isCancelled
          ? AssistantErrorCode.cancelled
          : error.code;
      return snapshot(stopped: token.isCancelled && !timedOut);
    } on TimeoutException {
      failure = AssistantErrorCode.timeout;
      return snapshot();
    } catch (_) {
      failure = AssistantErrorCode.unknown;
      return snapshot(stopped: token.isCancelled && !timedOut);
    } finally {
      deadline.cancel();
    }
  }

  Future<Map<String, Object?>> _executeTool(
    AssistantAgentToolCall call, {
    required int vehicleId,
    required AssistantAgentPeriod defaultPeriod,
    required VehicleExpenseCategoryScope defaultScope,
    required String? defaultYearMonth,
    required List<VehicleExpensePeriodResult> periods,
    required List<VehicleExpenseEvidence> evidence,
    required List<VehicleExpensePeerResult> peerComparisons,
    AssistantAgentProgress? onProgress,
  }) async {
    final requiresComparison =
        call.name == AssistantAgentToolName.compareVehicleExpensePeriods ||
        call.name == AssistantAgentToolName.inspectVehicleExpenseDrivers;
    final expected = requiresComparison
        ? const {'period', 'scope', 'comparisonPeriod'}
        : const {'period', 'scope'};
    _validateArguments(call.arguments, expected, optional: const {'yearMonth'});
    final rawYearMonth = call.arguments['yearMonth'];
    if (rawYearMonth != null &&
        (rawYearMonth is! String ||
            !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(rawYearMonth))) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final period = _enumArgument<AssistantAgentPeriod>(
      AssistantAgentPeriod.values,
      call.arguments['period'],
    );
    final scope = _enumArgument<VehicleExpenseCategoryScope>(
      VehicleExpenseCategoryScope.values,
      call.arguments['scope'],
    );
    final request = VehicleExpenseToolRequest(
      vehicleId: vehicleId,
      period: period ?? defaultPeriod,
      scope: scope ?? defaultScope,
      comparisonPeriod: requiresComparison
          ? _enumArgument<AssistantAgentPeriod>(
              AssistantAgentPeriod.values,
              call.arguments['comparisonPeriod'],
            )
          : null,
      yearMonth: rawYearMonth as String? ?? defaultYearMonth,
    );
    switch (call.name) {
      case AssistantAgentToolName.summarizeVehicleExpenses:
        onProgress?.call('正在读取${_periodLabel(request.period)}费用');
        final result = await _reader.readVehicleExpenses(request);
        _mergePeriod(periods, result);
        return _periodJson(result);
      case AssistantAgentToolName.compareVehicleExpensePeriods:
        final comparisonPeriod = request.comparisonPeriod!;
        onProgress?.call('正在对比前后费用');
        final current = await _reader.readVehicleExpenses(request);
        final previous = await _reader.readVehicleExpenses(
          VehicleExpenseToolRequest(
            vehicleId: vehicleId,
            period: comparisonPeriod,
            scope: request.scope,
            yearMonth:
                request.yearMonth == null ||
                    comparisonPeriod != AssistantAgentPeriod.previousMonth
                ? null
                : _previousMonth(request.yearMonth!),
          ),
        );
        _mergePeriod(periods, current);
        _mergePeriod(periods, previous);
        final changes = _categoryChanges(current, previous);
        evidence.addAll(changes);
        return {
          'current': _periodJson(current),
          'comparison': _periodJson(previous),
          'categoryChanges': [for (final item in changes) _evidenceJson(item)],
          'increasePercent': null,
          'increasePercentNote': 'Percentage omitted unless both comparable daily totals are complete and the base is nonzero.',
        };
      case AssistantAgentToolName.inspectVehicleExpenseDrivers:
        onProgress?.call('正在分析费用变化来源');
        final current = await _reader.readVehicleExpenses(request);
        final previous = await _reader.readVehicleExpenses(
          VehicleExpenseToolRequest(
            vehicleId: vehicleId,
            period: request.comparisonPeriod!,
            scope: request.scope,
            yearMonth:
                request.yearMonth == null ||
                    request.comparisonPeriod !=
                        AssistantAgentPeriod.previousMonth
                ? null
                : _previousMonth(request.yearMonth!),
          ),
        );
        _mergePeriod(periods, current);
        _mergePeriod(periods, previous);
        final changes = _categoryChanges(current, previous);
        evidence.addAll(changes);
        return {
          'period': _periodJson(current),
          'categoryContributions': [
            for (final item in changes) _evidenceJson(item),
          ],
          'comparison': _periodJson(previous),
        };
      case AssistantAgentToolName.comparePeerVehicleExpenses:
        onProgress?.call('正在参考同类车辆费用');
        final result = await _reader.comparePeerVehicleExpenses(request);
        _mergePeriod(periods, result.period);
        peerComparisons.add(result);
        return {
          'period': _periodJson(result.period),
          'category': result.category.name,
          'comparableVehicleCount': result.comparableVehicleCount,
          'peerMeanAmountCents': result.peerAmountCents,
          'targetAmountCents': result.targetAmountCents,
          'comparability': result.comparability.name,
          'targetWorkload': _workloadJson(result.targetWorkload),
          'peerWorkload': _workloadJson(result.peerWorkload),
          'note': result.note,
          'targetCentsPerKilometer': result.targetCentsPerKilometer,
          'peerMeanCentsPerKilometer': result.peerMeanCentsPerKilometer,
          'metricUnit': result.metricUnit?.name,
          'targetUnitCost': result.targetUnitCost,
          'peerUnitCost': result.peerUnitCost,
        };
    }
  }

  void _validateArguments(
    Map<String, Object?> arguments,
    Set<String> expected, {
    Set<String> optional = const {},
  }) {
    final allowed = {...expected, ...optional};
    if (arguments.keys.toSet().difference(allowed).isNotEmpty ||
        !arguments.keys.toSet().containsAll(expected)) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
  }

  T? _enumArgument<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw const AssistantProviderException(
      AssistantErrorCode.invalidProviderResponse,
    );
  }

  void _mergePeriod(
    List<VehicleExpensePeriodResult> periods,
    VehicleExpensePeriodResult result,
  ) {
    final index = periods.indexWhere(
      (item) =>
          item.startInclusive == result.startInclusive &&
          item.endExclusive == result.endExclusive &&
          item.granularity == result.granularity,
    );
    if (index < 0) {
      periods.add(result);
      return;
    }
    final existing = periods[index];
    final categories =
        <VehicleExpenseCategoryScope, VehicleExpenseCategoryResult>{
          for (final item in existing.categories) item.category: item,
          for (final item in result.categories) item.category: item,
        };
    final fuels = <String, VehicleFuelMonthResult>{
      for (final item in existing.fuelMonths)
        '${item.year}-${item.month}': item,
      for (final item in result.fuelMonths) '${item.year}-${item.month}': item,
    };
    periods[index] = VehicleExpensePeriodResult(
      startInclusive: existing.startInclusive,
      endExclusive: existing.endExclusive,
      granularity: existing.granularity,
      coverage:
          result.coverage == VehicleExpenseCoverage.complete ||
              existing.coverage == VehicleExpenseCoverage.complete
          ? VehicleExpenseCoverage.complete
          : result.coverage == VehicleExpenseCoverage.partial ||
                existing.coverage == VehicleExpenseCoverage.partial
          ? VehicleExpenseCoverage.partial
          : VehicleExpenseCoverage.unknown,
      categories: categories.values.toList(),
      fuelMonths: fuels.values.toList(),
      workload: result.workload ?? existing.workload,
      coverageNotes: {
        ...existing.coverageNotes,
        ...result.coverageNotes,
      }.toList(),
    );
  }

  List<VehicleExpenseEvidence> _categoryChanges(
    VehicleExpensePeriodResult current,
    VehicleExpensePeriodResult previous,
  ) {
    final deltas =
        <
          ({
            VehicleExpenseCategoryResult current,
            VehicleExpenseCategoryResult before,
            int delta,
          })
        >[];
    for (final category in current.categories) {
      if (category.category == VehicleExpenseCategoryScope.all) continue;
      final before = previous.categories
          .where((item) => item.category == category.category)
          .firstOrNull;
      if (before == null) continue;
      deltas.add((
        current: category,
        before: before,
        delta: category.amountCents - before.amountCents,
      ));
    }
    final netGrowth = deltas.fold<int>(0, (sum, item) {
      return _hasComparableFuelMonth(
            current,
            previous,
            item.current,
            item.before,
          )
          ? sum + item.delta
          : item.current.category == VehicleExpenseCategoryScope.fuel
          ? sum
          : sum + item.delta;
    });
    return [
      for (final item in deltas)
        VehicleExpenseEvidence(
          label: item.current.category.name,
          amountCents: item.current.amountCents,
          recordCount: item.current.recordCount,
          previousAmountCents: item.before.amountCents,
          deltaCents:
              item.current.category == VehicleExpenseCategoryScope.fuel &&
                  !_hasComparableFuelMonth(
                    current,
                    previous,
                    item.current,
                    item.before,
                  )
              ? null
              : item.delta,
          contributionBasis:
              item.current.category == VehicleExpenseCategoryScope.fuel
              ? '同一完整自然月有双方油费登记时比较登记金额；不代表实际支出完整。'
              : '同类别本期与前期登记金额差；登记覆盖未知时仅代表台账变化。',
          contributionPercent:
              netGrowth > 0 &&
                  item.delta > 0 &&
                  (item.current.category != VehicleExpenseCategoryScope.fuel ||
                      _hasComparableFuelMonth(
                        current,
                        previous,
                        item.current,
                        item.before,
                      ))
              ? item.delta * 100 / netGrowth
              : null,
        ),
    ];
  }

  bool _hasComparableFuelMonth(
    VehicleExpensePeriodResult currentPeriod,
    VehicleExpensePeriodResult previousPeriod,
    VehicleExpenseCategoryResult current,
    VehicleExpenseCategoryResult previous,
  ) {
    if (current.category != VehicleExpenseCategoryScope.fuel) return false;
    return current.recordCount > 0 &&
        previous.recordCount > 0 &&
        _isNaturalMonth(currentPeriod) &&
        _isNaturalMonth(previousPeriod);
  }

  bool _isNaturalMonth(VehicleExpensePeriodResult period) =>
      period.startInclusive.day == 1 &&
      period.endExclusive.day == 1 &&
      DateTime(period.startInclusive.year, period.startInclusive.month + 1) ==
          period.endExclusive;

  Map<String, Object?> _periodJson(VehicleExpensePeriodResult result) => {
    'startInclusive': _date(result.startInclusive),
    'endExclusive': _date(result.endExclusive),
    'granularity': result.granularity.name,
    'coverage': result.coverage.name,
    'categories': [
      for (final item in result.categories)
        {
          'category': item.category.name,
          'amountCents': item.amountCents,
          'recordCount': item.recordCount,
          'coverage': item.coverage.name,
        },
    ],
    'fuelMonths': [
      for (final item in result.fuelMonths)
        {
          'year': item.year,
          'month': item.month,
          'amountCents': item.amountCents,
          'liters': item.liters,
          'workDays': item.workDays,
          'mileage': item.mileage,
          'workHours': item.workHours,
          'coverage': item.coverage.name,
        },
    ],
    'workload': _workloadJson(result.workload),
    'coverageNotes': result.coverageNotes,
  };

  Map<String, Object?>? _workloadJson(VehicleExpenseWorkload? value) =>
      value == null
      ? null
      : {
          'mileage': value.mileage,
          'workDays': value.workDays,
          'workHours': value.workHours,
          'coverage': value.coverage.name,
        };

  Map<String, Object?> _evidenceJson(VehicleExpenseEvidence value) => {
    'label': value.label,
    'amountCents': value.amountCents,
    'recordCount': value.recordCount,
    'previousAmountCents': value.previousAmountCents,
    'deltaCents': value.deltaCents,
    'contributionBasis': value.contributionBasis,
    'contributionPercent': value.contributionPercent,
  };

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _previousMonth(String value) {
    final parts = value.split('-');
    final previous = DateTime(int.parse(parts[0]), int.parse(parts[1]) - 1);
    return '${previous.year.toString().padLeft(4, '0')}-${previous.month.toString().padLeft(2, '0')}';
  }

  String _previousMonthOfToday(DateTime today) {
    final previous = DateTime(today.year, today.month - 1);
    return '${previous.year.toString().padLeft(4, '0')}-${previous.month.toString().padLeft(2, '0')}';
  }

  Duration _remaining(DateTime startedAt) =>
      maxElapsed - _clock().difference(startedAt);

  String _periodLabel(AssistantAgentPeriod value) => switch (value) {
    AssistantAgentPeriod.recent30Days => '近30天',
    AssistantAgentPeriod.previous30Days => '前30天',
    AssistantAgentPeriod.previousMonth => '上月',
    AssistantAgentPeriod.recent90Days => '近90天',
  };

  String? _qualitativeOnly(String? text) {
    final normalized = text?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return RegExp(r'[0-9０-９零〇一二三四五六七八九十百千万亿两]').hasMatch(normalized)
        ? '分析已完成，具体金额、次数、期间与比较依据以本地计算结果为准。'
        : normalized;
  }
}
