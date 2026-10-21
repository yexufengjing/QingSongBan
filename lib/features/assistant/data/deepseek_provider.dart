import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/assistant_models.dart';
import 'assistant_outbound_projection.dart';

typedef DeepSeekTransport = Future<DeepSeekHttpResponse> Function({
  required Uri uri,
  required Map<String, String> headers,
  required String body,
  required Duration connectionTimeout,
  required Duration requestTimeout,
  required RequestToken token,
});

class DeepSeekHttpResponse {
  const DeepSeekHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// The default dart:io transport, exposed so its request encoding can be
/// verified against a local HTTP server.
class DeepSeekHttpClientTransport {
  const DeepSeekHttpClientTransport();

  Future<DeepSeekHttpResponse> call({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
    required Duration connectionTimeout,
    required Duration requestTimeout,
    required RequestToken token,
  }) => DeepSeekProvider._sendWithHttpClient(
    uri: uri,
    headers: headers,
    body: body,
    connectionTimeout: connectionTimeout,
    requestTimeout: requestTimeout,
    token: token,
  );
}

/// DeepSeek chat-completions adapter for intent parsing and explicit summary
/// explanation. It never sends local identity or attendance detail records.
class DeepSeekProvider
    implements AIProvider, AIProviderUsage, VehicleExpenseAgentProvider {
  DeepSeekProvider({
    required AssistantKeyStore keyStore,
    DeepSeekTransport? transport,
  })
    // The public constructor keeps its `keyStore` parameter name while the
    // implementation retains a private field.
    // ignore: prefer_initializing_formals
    : _keyStore = keyStore,
       _transport = transport ?? const DeepSeekHttpClientTransport().call;

  static final _endpoint = Uri.https('api.deepseek.com', '/chat/completions');
  static const model = 'deepseek-flash';
  static const connectionTimeout = Duration(seconds: 10);
  static const requestTimeout = Duration(seconds: 20);
  static const _parseTokenLimit = 512;
  static const _agentTokenLimit = 900;

  final AssistantKeyStore _keyStore;
  final DeepSeekTransport _transport;

  int requestCount = 0;
  int? inputTokens;
  int? outputTokens;
  Duration lastRequestDuration = Duration.zero;
  int _parseCalls = 0;
  int _explanationCalls = 0;
  int _connectionChecks = 0;
  int _agentCalls = 0;
  Duration _totalDuration = Duration.zero;
  final Map<int, _RequestUsage> _requestUsages = {};

  @override
  AIProviderUsageSnapshot get usageSnapshot => AIProviderUsageSnapshot(
    parseCalls: _parseCalls,
    explanationCalls: _explanationCalls,
    connectionChecks: _connectionChecks,
    agentCalls: _agentCalls,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    totalDuration: _totalDuration,
  );

  @override
  AIProviderUsageSnapshot usageForRequest(int requestId) {
    final usage = _requestUsages[requestId];
    return AIProviderUsageSnapshot(
      parseCalls: usage?.parseCalls ?? 0,
      explanationCalls: usage?.explanationCalls ?? 0,
      connectionChecks: usage?.connectionChecks ?? 0,
      agentCalls: usage?.agentCalls ?? 0,
      inputTokens: usage?.inputTokens,
      outputTokens: usage?.outputTokens,
      totalDuration: usage?.duration ?? Duration.zero,
    );
  }

  static final Map<String, Object?> _parameters = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'action',
      'employeeText',
      'year',
      'yearReference',
      'month',
      'clarification',
      'vehicleText',
      'allVehicles',
      'expenseCategory',
      'expensePeriod',
      'expenseYearMonth',
      'businessType',
      'businessSubject',
      'businessOperation',
    ],
    'properties': {
      'action': {
        'type': 'string',
        'enum': [
          'queryAttendance',
          'queryVehicleAnnualRepair',
          'queryVehicleAnnualRanking',
          'queryVehicleExpenseAnalysis',
          'queryBusiness',
          'changeYear',
          'changeEmployee',
          'changeVehicle',
          'allVehicles',
          'refresh',
          'clarify',
          'unsupported',
        ],
      },
      'employeeText': {
        'type': ['string', 'null'],
      },
      'year': {
        'type': ['integer', 'null'],
      },
      'yearReference': {
        'type': 'string',
        'enum': ['explicit', 'current', 'previous', 'inherit', 'unspecified'],
      },
      'month': {
        'type': ['integer', 'null'],
      },
      'clarification': {
        'type': ['string', 'null'],
      },
      'vehicleText': {
        'type': ['string', 'null'],
      },
      'allVehicles': {'type': 'boolean'},
      'expenseCategory': {
        'type': 'string',
        'enum': ['all', 'repair', 'maintenance', 'fuel', 'manual'],
      },
      'expensePeriod': {
        'type': 'string',
        'enum': [
          'recent30Days',
          'previous30Days',
          'previousMonth',
          'recent90Days',
        ],
      },
      'expenseYearMonth': {
        'type': ['string', 'null'],
      },
      'businessType': {
        'type': 'string',
        'enum': [
          'attendance', 'vehicleAnnualRepair', 'vehicleAnnualRanking', 'vehicleExpenseAnalysis',
          'personnel', 'payroll', 'inventory', 'purchase', 'distribution',
          'vehicleMaintenance', 'vehicleReminders', 'gardenRepair',
        ],
      },
      'businessSubject': {'type': ['string', 'null']},
      'businessOperation': {
        'type': 'string',
        'enum': ['summary', 'inherit', 'detail', 'lowStock', 'pending', 'partial', 'received', 'notReceived', 'monthlyTotal', 'comparePrice'],
      },
    },
  };

  @override
  Future<AttendanceIntent> parseIntent(
    IntentRequest request,
    RequestToken token,
  ) async {
    final context = <String, Object?>{
      'today': _dateOnly(request.now),
      if (request.previousAction != null)
        'previousAction': _actionName(request.previousAction!),
      if (request.previousYearMonth != null)
        'previousYearMonth': request.previousYearMonth,
      'hasPageEmployee': request.hasPageEmployee,
      if (request.pageYearMonth != null) 'pageYearMonth': request.pageYearMonth,
      'previousBusinessType': request.previousBusinessType.name,
      if (request.previousYear != null) 'previousYear': request.previousYear,
      'hasPageVehicle': request.hasPageVehicle,
      if (request.pageVehicleYear != null)
        'pageVehicleYear': request.pageVehicleYear,
      if (request.previousExpenseCategory != null)
        'previousExpenseCategory': request.previousExpenseCategory!.name,
      if (request.previousExpensePeriod != null)
        'previousExpensePeriod': request.previousExpensePeriod!.name,
      if (request.previousExpenseYearMonth != null)
        'previousExpenseYearMonth': request.previousExpenseYearMonth,
      if (request.previousBusinessQuestion != null)
        'previousBusinessQuestion': request.previousBusinessQuestion,
      if (request.previousBusinessOperation != null)
        'previousBusinessOperation': request.previousBusinessOperation,
      if (request.previousBusinessYearMonth != null)
        'previousBusinessYearMonth': request.previousBusinessYearMonth,
    };
    final body = _baseBody(
      messages: [
        {
          'role': 'system',
          'content':
              'Interpret a request for read-only monthly attendance, personnel, payroll, inventory, purchase, benefit distribution, vehicle repair progress/reminders, garden-tool repairs, a single '
              'vehicle annual repair summary, all-vehicle annual repair-cost '
              'ranking, or vehicle expense analysis. Fuzzy requests such as '
              '“这辆车最近怎么这么费钱” use queryVehicleExpenseAnalysis. '
              'Default expenseCategory to all and expensePeriod to recent30Days. '
              'For an explicitly named calendar month or year-month, set expenseYearMonth to '
              'YYYY-MM; the app validates it and uses a local month boundary. Otherwise null. '
              'An explicit expenseYearMonth always represents one calendar month; return '
              'expensePeriod=previousMonth as the canonical monthly period even if prior '
              'context had another period. For queryVehicleExpenseAnalysis, put an explicitly '
              'named calendar month only in expenseYearMonth (YYYY-MM); keep year=null, '
              'yearReference=unspecified, and month=null. Never duplicate that month in '
              'the attendance/business year or month fields. For example, a named vehicle '
              'expense request for October 2026 uses expenseYearMonth="2026-10", '
              'year=null, yearReference="unspecified", month=null. '
              'Use repair, maintenance, fuel, or manual only when the user narrows '
              'the category. Use previousMonth for an explicit last-month request. '
              'Short follow-ups such as “只看维修”, “换上个月”, or “和同类车比” '
              'remain queryVehicleExpenseAnalysis with vehicleText null; the app '
              'will run a multi-turn tool agent. Do not expose any database identity. '
              'When previousBusinessType is vehicleExpenseAnalysis, previous expense '
              'scope/period/yearMonth are provided in context. For a short follow-up, '
              'preserve each prior condition unless the user explicitly changes it; '
              '“只看维修” changes only category, “换上个月” changes only period, '
              'and “和同类车比” preserves the prior scope and period. '
              'A new explicit time phrase overrides prior period/month context. In particular, '
              '“最近” or “最近有没有比以前费钱” sets expensePeriod=recent30Days and '
              'expenseYearMonth=null, even if the previous query selected a calendar month. '
              'Only an explicit request such as “改看最近90天” or “查最近90天” sets '
              'expensePeriod=recent90Days. Conditional background wording such as '
              '“数据太少的话，再多看看前几个月” does not change the primary period: '
              'keep the primary recent30Days (or the explicitly requested primary period), '
              'and let the expense analysis agent decide whether broader periods are useful '
              'after reading the first result. '
              'ranking. Determine the business scope before checking whether '
              'a person, month, or vehicle is named. When the request clearly '
              'asks for attendance but omits the person, return queryAttendance '
              'with employeeText null so the app can ask locally. When the '
              'request clearly asks for vehicle repair costs but does not name '
              'a vehicle and does not explicitly request all vehicles, return '
              'queryVehicleAnnualRepair with vehicleText null so the app can '
              'ask locally. For example, “查维修费用” is a single-vehicle '
              'query with a missing vehicle. Do not use clarify merely to ask '
              'for a missing person, month, or vehicle when the supported task '
              'scope is clear; use clarify only when the scope itself cannot '
              'be determined from the request and supplied context. When '
              'switching from all-vehicle ranking to one named vehicle, use '
              'queryVehicleAnnualRepair, set allVehicles false, and put only '
              'the explicit vehicle name or number in vehicleText. For example, '
              'after a ranking, “查一下V03去年全年的维修费用” is a '
              'queryVehicleAnnualRepair request with vehicleText V03, '
              'yearReference previous, year null, and allVehicles false; do not '
              'turn it into changeYear for the ranking. When the user only '
              'changes the year of the current single-vehicle query, keep the '
              'changeYear action and vehicle context: “改看今年的” uses '
              'yearReference current, year null, vehicleText null, and '
              'allVehicles false. Do not change a single-vehicle task to all '
              'vehicles unless the user explicitly asks for all vehicles. Do not '
              'calculate facts, choose a database object, or '
              'perform a business operation. Return exactly one '
              'prepareAssistantQuery call with every schema field. '
              'queryAttendance covers monthly attendance and the attendance, '
              'leave/rest, or overtime summary for one person. '
              'A request such as last month’s overtime duration summary is '
              'still a queryAttendance request. '
              'queryVehicleAnnualRepair covers one vehicle and its annual '
              'completed-repair actual-cost summary. queryVehicleAnnualRanking '
              'covers the complete non-deleted vehicle set. For that action, '
              'allVehicles must be true and vehicleText null. changeYear '
              'corrects the year for the previous applicable task; '
              'changeEmployee and changeVehicle correct its named object; '
              'refresh is only for an explicit refresh request; clarify asks '
              'one missing necessary condition; unsupported covers business '
              'writes or unrelated tasks. '
              'expensePeriod recent30Days means the app localizes the last 30 '
              'natural days including today; never compute dates. '
              'queryBusiness covers personnel, payroll, inventory, purchase, item distribution, vehicle repair progress/reminders, and garden-tool repair records. Set businessType to the best matching domain. Preserve the full request meaning for local calculations. Short follow-ups such as “按上个月看”, “那采购呢”, “这批谁领了”, or “维修贵在哪里” should keep the current domain unless a new domain is explicit. Use unsupported for writes or unrelated tasks. '
              'For queryBusiness, set businessSubject to only the explicitly named person, material, purchase, vehicle, reminder subject, or garden repair project/model; use null for anaphora or no named subject so the app can inherit local context. Never invent a subject. Set businessOperation according to intent: lowStock for low stock, pending for pending/not received purchase, partial for partially received purchase, received/notReceived for welfare claim states, monthlyTotal for month costs, comparePrice for unit price comparisons, detail for one named item/person/request/vehicle, summary for a new broad query, inherit for a short follow-up that only changes time or continues the previous condition. '
              'For relative month changes such as “那上个月呢” or “改看上个月”, calculate the requested calendar month using previousBusinessYearMonth when continuing the same business domain; otherwise use today. Return yearReference=explicit with the resulting year and month, even when crossing a year boundary. previousBusinessYearMonth is only a time anchor, not a filter to retain: keep the prior month only when the follow-up has no date change. Do not return businessOperation=inherit with a null month when the user explicitly changes the month. For a short follow-up with no date phrase, keep month null so the app inherits the previous month. '
              'For every queryBusiness request, place a named person only in businessSubject; set employeeText=null, vehicleText=null, and allVehicles=false. The complete fields for “查2026年10月陈晨的工资异常和实发金额” are {"action":"queryBusiness","employeeText":null,"year":2026,"yearReference":"explicit","month":10,"clarification":null,"vehicleText":null,"allVehicles":false,"expenseCategory":"all","expensePeriod":"recent30Days","expenseYearMonth":null,"businessType":"payroll","businessSubject":"陈晨","businessOperation":"detail"}. The example name is fictional. For vehicle repair/reminder queryBusiness, put the named vehicle only in businessSubject and leave vehicleText null. Keep businessSubject null for pronouns so local same-domain context can be inherited. '
              'For vehicleMaintenance, businessSubject must contain only one named vehicle name, number, or plate. If the question also names a fault or repair symptom, do not append that symptom or the requested status/cost words to businessSubject; preserve them in the original question. Example: for “甲号车出现刹车异响，维修到哪一步、实际花了多少钱”, businessSubject is only “甲号车”. '
              'For gardenRepair, businessSubject must contain only the named repair project or tool/model, not its size specification or count unit. Keep specification and unit conditions such as “40厘米” and “按片” in the original question; local reading filters the selected project records by those conditions. '
              'For queryAttendance, employeeText contains only the explicitly named person’s raw '
              'name or identifier value. Remove a field label only when it is '
              'clearly separate from the value, such as 工号：E001 yielding E001. '
              'Preserve a continuous Chinese name span exactly as written; do '
              'not remove words such as 员工 or 人员 when they occur inside that '
              'span. Preserve identifier characters exactly, including leading '
              'zeroes. For pronouns such as he/that person use null so '
              'the app can inherit its local selected person. year is present only '
              'with yearReference=explicit. Use current for this calendar '
              'year, previous for last calendar year, inherit only for a '
              'follow-up using supplied context, and unspecified when absent. '
              'The app computes current/previous years from today. Use a month '
              'only when the user states it; otherwise return null and let the '
              'app apply page or conversation context, or ask if none exists. '
              'If the user explicitly states a numeric month outside 1 to 12, '
              'preserve that number unchanged in month (for example, 13); do '
              'not replace it with null or ask for a month. The app validates '
              'it locally. For every unsupported request, still return exactly '
              'one prepareAssistantQuery call with all fields in this complete '
              'object: {"action":"unsupported","employeeText":null,'
              '"year":null,"yearReference":"unspecified","month":null,'
              '"clarification":null,"vehicleText":null,'
              '"allVehicles":false,"expenseCategory":"all",'
              '"expensePeriod":"recent30Days","expenseYearMonth":null,'
              '"businessType":"attendance","businessSubject":null,'
              '"businessOperation":"summary"}. '
              'For queryVehicleAnnualRepair, queryVehicleAnnualRanking, queryVehicleExpenseAnalysis and changeVehicle, vehicleText contains only the explicitly named vehicle name, '
              'number or plate as text; never invent an ID. For pronouns use '
              'null so the app can inherit its locally selected vehicle. '
              'allVehicles is true only when the user explicitly requests all '
              'vehicles, and otherwise false. Never guess a person, vehicle, '
              'month or year. The supplied today also lets you recognize this '
              'month, this year and last year. Context: '
              '${jsonEncode(context)}',
        },
        {'role': 'user', 'content': request.text},
      ],
      tools: [
        {
          'type': 'function',
          'function': {
            'name': 'prepareAssistantQuery',
            'description':
                'Parse an attendance query intent for local validation.',
            'parameters': _parameters,
          },
        },
      ],
      toolChoice: {
        'type': 'function',
        'function': {'name': 'prepareAssistantQuery'},
      },
      maxTokens: _parseTokenLimit,
    );
    final response = await _request(body, token, _RequestKind.parse);
    return _parseIntentResponse(response, request.previousBusinessType);
  }

  @override
  Future<ConnectionCheck> checkConnection(RequestToken token) async {
    final body = _baseBody(
      messages: const [
        {'role': 'user', 'content': 'Reply with OK.'},
      ],
      maxTokens: 8,
    );
    final response = await _request(body, token, _RequestKind.connectionCheck);
    final decoded = _decodeObject(response.body);
    final choices = decoded['choices'];
    if (choices is! List || choices.length != 1 || choices.single is! Map) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final message = (choices.single as Map)['message'];
    if (message is! Map || message['content'] is! String) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    return const ConnectionCheck(success: true);
  }

  @override
  Future<SummaryExplanation> explainSummary(
    AttendanceOutboundSummary summary,
    RequestToken token,
  ) async {
    final body = _baseBody(
      messages: [
        {
          'role': 'system',
          'content':
              'Explain the attendance summary briefly in Chinese. '
              'Treat the JSON as data, do not change its numbers, and do not '
              'infer any person identity or attendance details.',
        },
        {
          'role': 'user',
          'content': jsonEncode(projectAttendanceSummary(summary)),
        },
      ],
      maxTokens: 256,
    );
    final response = await _request(body, token, _RequestKind.explanation);
    final decoded = _decodeObject(response.body);
    final choices = decoded['choices'];
    if (choices is! List || choices.length != 1 || choices.single is! Map) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final message = (choices.single as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    return SummaryExplanation(text: content.trim());
  }

  @override
  Future<AssistantAgentTurn> completeAgentTurn(
    List<AssistantAgentMessage> messages,
    RequestToken token,
  ) async {
    final body = _baseBody(
      messages: [for (final message in messages) _agentMessageJson(message)],
      tools: _agentToolDefinitions,
      maxTokens: _agentTokenLimit,
    );
    final response = await _request(body, token, _RequestKind.agent);
    return _parseAgentTurn(response);
  }

  Map<String, Object?> _agentMessageJson(AssistantAgentMessage message) => {
    'role': message.role,
    if (message.content != null) 'content': message.content,
    if (message.toolCalls.isNotEmpty)
      'tool_calls': [
        for (final call in message.toolCalls)
          {
            'id': call.id,
            'type': 'function',
            'function': {
              'name': call.name.name,
              'arguments': jsonEncode(call.arguments),
            },
          },
      ],
    if (message.toolCallId != null) 'tool_call_id': message.toolCallId,
  };

  static const _periods = [
    'recent30Days',
    'previous30Days',
    'previousMonth',
    'recent90Days',
  ];
  static const _scopes = ['all', 'repair', 'maintenance', 'fuel', 'manual'];
  static final List<Map<String, Object?>> _agentToolDefinitions = [
    for (final tool in [
      (
        'summarizeVehicleExpenses',
        'Read aggregate expenses for one period.',
        false,
      ),
      (
        'compareVehicleExpensePeriods',
        'Compare current and prior period aggregates.',
        true,
      ),
      (
        'inspectVehicleExpenseDrivers',
        'Calculate category contribution to period changes.',
        true,
      ),
      (
        'comparePeerVehicleExpenses',
        'Compare anonymized same-model vehicle aggregates.',
        false,
      ),
    ])
      {
        'type': 'function',
        'function': {
          'name': tool.$1,
          'description': tool.$2,
          'parameters': {
            'type': 'object',
            'additionalProperties': false,
            'required': ['period', 'scope', if (tool.$3) 'comparisonPeriod'],
            'properties': {
              'period': {'type': 'string', 'enum': _periods},
              'scope': {'type': 'string', 'enum': _scopes},
              if (tool.$3)
                'comparisonPeriod': {'type': 'string', 'enum': _periods},
              'yearMonth': {
                'type': ['string', 'null'],
              },
            },
          },
        },
      },
  ];

  AssistantAgentTurn _parseAgentTurn(DeepSeekHttpResponse response) {
    final decoded = _decodeObject(response.body);
    final choices = decoded['choices'];
    if (choices is! List || choices.length != 1 || choices.single is! Map) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final choice = choices.single as Map;
    if (choice['finish_reason'] == 'length') {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final message = choice['message'];
    if (message is! Map) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final rawCalls = message['tool_calls'];
    if (rawCalls != null) {
      if (rawCalls is! List || rawCalls.isEmpty) {
        throw const AssistantProviderException(
          AssistantErrorCode.invalidProviderResponse,
        );
      }
      final calls = <AssistantAgentToolCall>[];
      for (final raw in rawCalls) {
        if (raw is! Map ||
            raw['id'] is! String ||
            (raw['id'] as String).isEmpty) {
          throw const AssistantProviderException(
            AssistantErrorCode.invalidProviderResponse,
          );
        }
        final function = raw['function'];
        if (function is! Map ||
            function['name'] is! String ||
            function['arguments'] is! String) {
          throw const AssistantProviderException(
            AssistantErrorCode.invalidProviderResponse,
          );
        }
        final name = AssistantAgentToolName.values
            .where((item) => item.name == function['name'])
            .firstOrNull;
        if (name == null) {
          throw const AssistantProviderException(
            AssistantErrorCode.invalidProviderResponse,
          );
        }
        final arguments = _decodeObject(function['arguments'] as String);
        calls.add(
          AssistantAgentToolCall(
            id: raw['id'] as String,
            name: name,
            arguments: arguments,
          ),
        );
      }
      return AssistantAgentTurn(
        text: message['content'] is String
            ? (message['content'] as String).trim()
            : null,
        toolCalls: calls,
      );
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    return AssistantAgentTurn(text: content.trim());
  }

  Map<String, Object?> _baseBody({
    required List<Map<String, Object?>> messages,
    List<Map<String, Object?>>? tools,
    Map<String, Object?>? toolChoice,
    required int maxTokens,
  }) => {
    'model': model,
    'messages': messages,
    'stream': false,
    'max_tokens': maxTokens,
    'thinking': {'type': 'disabled'},
    'tools': ?tools,
    'tool_choice': ?toolChoice,
  };

  Future<DeepSeekHttpResponse> _request(
    Map<String, Object?> body,
    RequestToken token,
    _RequestKind kind,
  ) async {
    if (token.isCancelled) {
      throw const AssistantProviderException(AssistantErrorCode.cancelled);
    }
    final key = await _keyStore.readKey();
    if (key == null || key.trim().isEmpty) {
      throw const AssistantProviderException(AssistantErrorCode.missingApiKey);
    }
    final stopwatch = Stopwatch()..start();
    requestCount++;
    final requestUsage = _requestUsages.putIfAbsent(token.id, _RequestUsage.new)
      ..record(kind);
    switch (kind) {
      case _RequestKind.parse:
        _parseCalls++;
      case _RequestKind.explanation:
        _explanationCalls++;
      case _RequestKind.connectionCheck:
        _connectionChecks++;
      case _RequestKind.agent:
        _agentCalls++;
    }
    try {
      final response = await _transport(
        uri: _endpoint,
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer ${key.trim()}',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
        body: jsonEncode(body),
        connectionTimeout: connectionTimeout,
        requestTimeout: requestTimeout,
        token: token,
      ).timeout(requestTimeout);
      lastRequestDuration = stopwatch.elapsed;
      if (token.isCancelled) {
        throw const AssistantProviderException(AssistantErrorCode.cancelled);
      }
      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        throw AssistantProviderException(
          AssistantErrorCode.unauthorized,
          httpStatus: response.statusCode,
        );
      }
      if (response.statusCode == HttpStatus.tooManyRequests) {
        throw AssistantProviderException(
          AssistantErrorCode.rateLimited,
          httpStatus: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AssistantProviderException(
          AssistantErrorCode.providerUnavailable,
          httpStatus: response.statusCode,
        );
      }
      final decoded = _decodeObject(response.body);
      final usage = decoded['usage'];
      if (usage is Map) {
        inputTokens = usage['prompt_tokens'] is int
            ? (inputTokens ?? 0) + (usage['prompt_tokens'] as int)
            : inputTokens;
        outputTokens = usage['completion_tokens'] is int
            ? (outputTokens ?? 0) + (usage['completion_tokens'] as int)
            : outputTokens;
        if (usage['prompt_tokens'] is int) {
          requestUsage.inputTokens =
              (requestUsage.inputTokens ?? 0) + (usage['prompt_tokens'] as int);
        }
        if (usage['completion_tokens'] is int) {
          requestUsage.outputTokens =
              (requestUsage.outputTokens ?? 0) +
              (usage['completion_tokens'] as int);
        }
      }
      return response;
    } on AssistantProviderException {
      rethrow;
    } on TimeoutException {
      lastRequestDuration = stopwatch.elapsed;
      if (token.isCancelled) {
        throw const AssistantProviderException(AssistantErrorCode.cancelled);
      }
      throw const AssistantProviderException(AssistantErrorCode.timeout);
    } on SocketException {
      lastRequestDuration = stopwatch.elapsed;
      if (token.isCancelled) {
        throw const AssistantProviderException(AssistantErrorCode.cancelled);
      }
      throw const AssistantProviderException(AssistantErrorCode.network);
    } on FormatException {
      lastRequestDuration = stopwatch.elapsed;
      if (token.isCancelled) {
        throw const AssistantProviderException(AssistantErrorCode.cancelled);
      }
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    } catch (_) {
      lastRequestDuration = stopwatch.elapsed;
      if (token.isCancelled) {
        throw const AssistantProviderException(AssistantErrorCode.cancelled);
      }
      throw const AssistantProviderException(AssistantErrorCode.network);
    } finally {
      stopwatch.stop();
      lastRequestDuration = stopwatch.elapsed;
      _totalDuration += lastRequestDuration;
      requestUsage.duration += stopwatch.elapsed;
    }
  }

  AttendanceIntent _parseIntentResponse(
    DeepSeekHttpResponse response,
    AssistantBusinessType previousBusinessType,
  ) {
    Map<String, Object?> decoded;
    try {
      decoded = _decodeObject(response.body);
    } on FormatException {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.length != 1 || choices.single is! Map) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final choice = choices.single as Map;
    if (choice['finish_reason'] == 'length') {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final message = choice['message'];
    final calls = message is Map ? message['tool_calls'] : null;
    if (calls is! List || calls.length != 1 || calls.single is! Map) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final call = calls.single as Map;
    final function = call['function'];
    if (function is! Map || function['name'] != 'prepareAssistantQuery') {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final arguments = function['arguments'];
    if (arguments is! String) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    final Map<String, Object?> params;
    try {
      params = _decodeObject(arguments);
    } on FormatException {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    const allowed = {
      'action',
      'employeeText',
      'year',
      'yearReference',
      'month',
      'clarification',
      'vehicleText',
      'allVehicles',
      'expenseCategory',
      'expensePeriod',
      'expenseYearMonth',
      'businessType',
      'businessSubject',
      'businessOperation',
    };
    if (params.keys.toSet().difference(allowed).isNotEmpty ||
        !params.keys.toSet().containsAll(allowed)) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }

    final AttendanceAction action;
    final YearReference yearReference;
    final VehicleExpenseCategoryScope expenseCategory;
    final AssistantAgentPeriod expensePeriod;
    final AssistantBusinessType businessType;
    final businessSubject = params['businessSubject'];
    final businessOperation = params['businessOperation'];
    try {
      action = _parseEnum(AttendanceAction.values, params['action']);
      yearReference = _parseEnum(YearReference.values, params['yearReference']);
      expenseCategory = _parseEnum(
        VehicleExpenseCategoryScope.values,
        params['expenseCategory'],
      );
      expensePeriod = _parseEnum(
        AssistantAgentPeriod.values,
        params['expensePeriod'],
      );
      businessType = _parseEnum(AssistantBusinessType.values, params['businessType']);
    } on AssistantProviderException {
      rethrow;
    }
    final employeeText = params['employeeText'];
    final year = params['year'];
    final month = params['month'];
    final clarification = params['clarification'];
    final vehicleText = params['vehicleText'];
    final allVehicles = params['allVehicles'];
    final expenseYearMonth = params['expenseYearMonth'];
    if ((employeeText != null && employeeText is! String) ||
        (clarification != null && clarification is! String) ||
        (businessSubject != null && businessSubject is! String) ||
        businessOperation is! String || !const {'summary','inherit','detail','lowStock','pending','partial','received','notReceived','monthlyTotal','comparePrice'}.contains(businessOperation) ||
        (vehicleText != null && vehicleText is! String) ||
        allVehicles is! bool ||
        (expenseYearMonth != null &&
            (expenseYearMonth is! String ||
                !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$')
                    .hasMatch(expenseYearMonth))) ||
        (year != null && year is! int) ||
        (month != null && month is! int) ||
        (month is int && (month < 1 || month > 12)) ||
        (year is int && (year < 1900 || year > 9999)) ||
        (yearReference == YearReference.explicit && year is! int) ||
        (yearReference != YearReference.explicit && year != null)) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    if (!_hasCompatibleActionFields(
      action,
      previousBusinessType,
      employeeText: employeeText as String?,
      month: month as int?,
      vehicleText: vehicleText as String?,
      allVehicles: allVehicles,
      expenseYearMonth: expenseYearMonth as String?,
    )) {
      throw const AssistantProviderException(
        AssistantErrorCode.invalidProviderResponse,
      );
    }
    return AttendanceIntent(
      action: action,
      employeeText: employeeText,
      year: year as int?,
      yearReference: yearReference,
      month: month,
      clarification: clarification as String?,
      vehicleText: vehicleText,
      allVehicles: allVehicles,
      expenseCategory: expenseCategory,
      expensePeriod: expenseYearMonth == null
          ? expensePeriod
          : AssistantAgentPeriod.previousMonth,
      expenseYearMonth: expenseYearMonth,
      businessType: businessType,
      businessSubject: businessSubject as String?,
      businessOperation: businessOperation,
    );
  }

  static bool _hasCompatibleActionFields(
    AttendanceAction action,
    AssistantBusinessType previousBusinessType, {
    required String? employeeText,
    required int? month,
    required String? vehicleText,
    required bool allVehicles,
    required String? expenseYearMonth,
  }) {
    bool noVehicleFields() => vehicleText == null && !allVehicles;
    bool noAttendanceFields() => employeeText == null && month == null;
    bool noBusinessConflictFields() => employeeText == null && noVehicleFields();

    if (action != AttendanceAction.queryVehicleExpenseAnalysis &&
        expenseYearMonth != null) {
      return false;
    }

    return switch (action) {
      AttendanceAction.queryAttendance ||
      AttendanceAction.changeEmployee => noVehicleFields(),
      AttendanceAction.queryBusiness => noBusinessConflictFields(),
      AttendanceAction.queryVehicleAnnualRepair ||
      AttendanceAction.changeVehicle => noAttendanceFields() && !allVehicles,
      AttendanceAction.queryVehicleExpenseAnalysis =>
        noAttendanceFields() && !allVehicles,
      AttendanceAction.queryVehicleAnnualRanking ||
      AttendanceAction.allVehicles =>
        noAttendanceFields() && vehicleText == null && allVehicles,
      AttendanceAction.changeYear ||
      AttendanceAction.refresh ||
      AttendanceAction.nextRankingPage => switch (previousBusinessType) {
        AssistantBusinessType.attendance => noVehicleFields(),
        AssistantBusinessType.vehicleAnnualRepair =>
          noAttendanceFields() && !allVehicles,
        AssistantBusinessType.vehicleAnnualRanking =>
          noAttendanceFields() && vehicleText == null,
        AssistantBusinessType.vehicleExpenseAnalysis =>
          noAttendanceFields() && !allVehicles,
        AssistantBusinessType.personnel ||
        AssistantBusinessType.payroll ||
        AssistantBusinessType.inventory ||
        AssistantBusinessType.purchase ||
        AssistantBusinessType.distribution ||
        AssistantBusinessType.vehicleMaintenance ||
        AssistantBusinessType.vehicleReminders ||
        AssistantBusinessType.gardenRepair => noBusinessConflictFields(),
      },
      AttendanceAction.clarify => !allVehicles,
      AttendanceAction.unsupported => expenseYearMonth == null,
    };
  }

  static T _parseEnum<T extends Enum>(List<T> values, Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw const AssistantProviderException(
      AssistantErrorCode.invalidProviderResponse,
    );
  }

  static Map<String, Object?> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  static String _actionName(AttendanceAction action) => action.name;

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Future<DeepSeekHttpResponse> _sendWithHttpClient({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
    required Duration connectionTimeout,
    required Duration requestTimeout,
    required RequestToken token,
  }) async {
    final client = HttpClient()..connectionTimeout = connectionTimeout;
    HttpClientRequest? request;
    var finished = false;
    final detachCancelHandler = token.addCancelHandler(() {
      if (finished) return;
      request?.abort(const SocketException('Request cancelled.'));
      client.close(force: true);
    });
    try {
      final activeRequest = await client.postUrl(uri).timeout(requestTimeout);
      request = activeRequest;
      headers.forEach(activeRequest.headers.set);
      final bodyBytes = utf8.encode(body);
      activeRequest.contentLength = bodyBytes.length;
      activeRequest.add(bodyBytes);
      final response = await activeRequest.close().timeout(requestTimeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);
      return DeepSeekHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      finished = true;
      detachCancelHandler();
      client.close(force: true);
    }
  }
}

enum _RequestKind { parse, explanation, connectionCheck, agent }

class _RequestUsage {
  int parseCalls = 0;
  int explanationCalls = 0;
  int connectionChecks = 0;
  int agentCalls = 0;
  int? inputTokens;
  int? outputTokens;
  Duration duration = Duration.zero;

  void record(_RequestKind kind) {
    switch (kind) {
      case _RequestKind.parse:
        parseCalls++;
      case _RequestKind.explanation:
        explanationCalls++;
      case _RequestKind.connectionCheck:
        connectionChecks++;
      case _RequestKind.agent:
        agentCalls++;
    }
  }
}
