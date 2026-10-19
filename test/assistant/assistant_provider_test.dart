import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/data/deepseek_provider.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  group('DeepSeekProvider', () {
    test(
      'default HTTP transport sends Chinese JSON as UTF-8 to local server',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final received = Completer<Map<String, dynamic>>();
        server.listen((request) async {
          final bytes = await request.fold<List<int>>(
            <int>[],
            (collected, chunk) => collected..addAll(chunk),
          );
          received.complete({
            'contentLength': request.contentLength,
            'json': jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
          });
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"ok":true}');
          await request.response.close();
        });
        final requestBodyJson = jsonEncode({'message': '中文查询'});

        try {
          final response = await const DeepSeekHttpClientTransport().call(
            uri: Uri(
              scheme: 'http',
              host: InternetAddress.loopbackIPv4.address,
              port: server.port,
              path: '/echo',
            ),
            headers: const {'content-type': 'application/json'},
            body: requestBodyJson,
            connectionTimeout: const Duration(seconds: 2),
            requestTimeout: const Duration(seconds: 2),
            token: RequestToken(),
          );
          final requestBody = await received.future.timeout(
            const Duration(seconds: 2),
          );

          expect(
            requestBody['contentLength'],
            utf8.encode(requestBodyJson).length,
          );
          expect(
            (requestBody['json'] as Map<String, dynamic>)['message'],
            '中文查询',
          );
          expect(response.statusCode, HttpStatus.ok);
          expect(response.body, '{"ok":true}');
        } finally {
          await server.close(force: true);
        }
      },
    );

    test('sends one named tool request and validates parsed intent', () async {
      final store = _KeyStore('secret-test-key');
      Map<String, dynamic>? sent;
      Map<String, String>? sentHeaders;
      final provider = DeepSeekProvider(
        keyStore: store,
        transport:
            ({
              required uri,
              required headers,
              required body,
              required connectionTimeout,
              required requestTimeout,
              required token,
            }) async {
              sent = jsonDecode(body) as Map<String, dynamic>;
              sentHeaders = headers;
              return DeepSeekHttpResponse(
                statusCode: 200,
                body: _toolResponse(_validArguments()),
              );
            },
      );

      final result = await provider.parseIntent(
        IntentRequest(
          text: '查王敏去年9月考勤',
          now: DateTime(2026, 10, 17),
          previousYearMonth: '2026-08',
          pageYearMonth: '2026-09',
        ),
        RequestToken(1),
      );

      expect(result.action, AttendanceAction.queryAttendance);
      expect(result.employeeText, '王敏');
      expect(result.year, isNull);
      expect(result.yearReference, YearReference.previous);
      expect(result.month, 9);
      expect(sentHeaders?['authorization'], 'Bearer secret-test-key');
      expect(sent?['model'], 'deepseek-flash');
      expect(sent?['stream'], isFalse);
      expect(sent?['thinking'], {'type': 'disabled'});
      expect(sent?['tool_choice'], {
        'type': 'function',
        'function': {'name': 'prepareAssistantQuery'},
      });
      final messages = sent?['messages'] as List;
      expect(messages.last['content'], '查王敏去年9月考勤');
      expect(jsonEncode(sent), isNot(contains('employeeId')));
      final tool = (sent?['tools'] as List).single as Map<String, dynamic>;
      final function = tool['function'] as Map<String, dynamic>;
      final parameters = function['parameters'] as Map<String, dynamic>;
      final requiredKeys = (parameters['required'] as List).cast<String>();
      expect(_validArguments().keys.toSet(), requiredKeys.toSet());
      expect(
        (parameters['properties'] as Map<String, dynamic>).keys.toSet(),
        requiredKeys.toSet(),
      );
      expect(provider.usageSnapshot.parseCalls, 1);
      expect(provider.usageSnapshot.inputTokens, 12);
      expect(provider.usageSnapshot.outputTokens, 5);
    });

    test(
      'preserves the multi-turn tool protocol and per-task usage totals',
      () async {
        final sentBodies = <Map<String, dynamic>>[];
        final responses = <String>[
          _toolResponse(_validArguments()),
          _agentToolResponse(
            content: '先检查费用变化。',
            id: 'call_compare_1',
            name: 'compareVehicleExpensePeriods',
            arguments: {
              'period': 'recent30Days',
              'comparisonPeriod': 'previous30Days',
              'scope': 'all',
            },
            promptTokens: 20,
            completionTokens: 7,
          ),
          _agentTextResponse(
            '已根据本地比较结果完成分析。',
            promptTokens: 31,
            completionTokens: 9,
          ),
        ];
        final provider = DeepSeekProvider(
          keyStore: _KeyStore('key'),
          transport:
              ({
                required uri,
                required headers,
                required body,
                required connectionTimeout,
                required requestTimeout,
                required token,
              }) async {
                sentBodies.add(jsonDecode(body) as Map<String, dynamic>);
                return DeepSeekHttpResponse(
                  statusCode: 200,
                  body: responses.removeAt(0),
                );
              },
        );
        final token = RequestToken(77);

        await provider.parseIntent(
          IntentRequest(text: '这辆车最近费用怎么样', now: DateTime(2026, 10, 18)),
          token,
        );
        final first = await provider.completeAgentTurn(const [
          AssistantAgentMessage(role: 'user', content: '先查近期费用'),
        ], token);
        expect(first.text, '先检查费用变化。');
        expect(first.toolCalls.single.id, 'call_compare_1');
        final second = await provider.completeAgentTurn([
          const AssistantAgentMessage(role: 'user', content: '先查近期费用'),
          AssistantAgentMessage(
            role: 'assistant',
            content: first.text,
            toolCalls: first.toolCalls,
          ),
          const AssistantAgentMessage(
            role: 'tool',
            toolCallId: 'call_compare_1',
            content: '{"current":{"amountCents":250000}}',
          ),
        ], token);

        expect(second.toolCalls, isEmpty);
        expect(second.text, '已根据本地比较结果完成分析。');
        final secondMessages = sentBodies.last['messages'] as List;
        final assistantToolMessage = secondMessages[1] as Map;
        expect(assistantToolMessage['content'], '先检查费用变化。');
        expect(assistantToolMessage['tool_calls'], [
          {
            'id': 'call_compare_1',
            'type': 'function',
            'function': {
              'name': 'compareVehicleExpensePeriods',
              'arguments': '{"period":"recent30Days","comparisonPeriod":"previous30Days","scope":"all"}',
            },
          },
        ]);
        expect(secondMessages[2]['role'], 'tool');
        expect(secondMessages[2]['tool_call_id'], 'call_compare_1');
        final usage = provider.usageForRequest(token.id);
        expect(usage.parseCalls, 1);
        expect(usage.agentCalls, 2);
        expect(usage.inputTokens, 63);
        expect(usage.outputTokens, 21);
        expect(usage.requestCount, 3);
      },
    );

    test(
      'keeps primary expense periods distinct from conditional background',
      () async {
        final cases = [
          (
            text: '这车最近有没有比以前费钱？数据太少的话，多看看前几个月。',
            period: AssistantAgentPeriod.recent30Days,
            yearMonth: null,
            modelPeriod: 'recent30Days',
            modelYearMonth: null,
          ),
          (
            text: '改看最近90天',
            period: AssistantAgentPeriod.recent90Days,
            yearMonth: null,
            modelPeriod: 'recent90Days',
            modelYearMonth: null,
          ),
          (
            text: '看看2026年9月油费',
            period: AssistantAgentPeriod.previousMonth,
            yearMonth: '2026-09',
            modelPeriod: 'recent90Days',
            modelYearMonth: '2026-09',
          ),
        ];

        for (final item in cases) {
          Map<String, dynamic>? sent;
          final provider = DeepSeekProvider(
            keyStore: _KeyStore('key'),
            transport:
                ({
                  required uri,
                  required headers,
                  required body,
                  required connectionTimeout,
                  required requestTimeout,
                  required token,
                }) async {
                  sent = jsonDecode(body) as Map<String, dynamic>;
                  return DeepSeekHttpResponse(
                    statusCode: 200,
                    body: _toolResponse(
                      _vehicleExpenseArguments(
                        period: item.modelPeriod,
                        yearMonth: item.modelYearMonth,
                      ),
                    ),
                  );
                },
          );

          final intent = await provider.parseIntent(
            IntentRequest(
              text: item.text,
              now: DateTime(2026, 10, 18),
              previousBusinessType:
                  AssistantBusinessType.vehicleExpenseAnalysis,
              previousExpenseCategory: VehicleExpenseCategoryScope.fuel,
              previousExpensePeriod: AssistantAgentPeriod.previousMonth,
              previousExpenseYearMonth: '2026-09',
            ),
            RequestToken(),
          );

          expect(intent.action, AttendanceAction.queryVehicleExpenseAnalysis);
          expect(intent.expensePeriod, item.period);
          expect(intent.expenseYearMonth, item.yearMonth);
          final messages = sent!['messages'] as List;
          final systemPrompt = messages.first['content'] as String;
          expect(systemPrompt, contains('Conditional background wording'));
          expect(systemPrompt, contains('改看最近90天'));
          expect(systemPrompt, contains('expenseYearMonth=null'));
          expect(systemPrompt, contains('previousExpenseYearMonth":"2026-09"'));
        }
      },
    );

    test('parses an employee identifier and its explicit month', () async {
      Map<String, dynamic>? sent;
      final provider = DeepSeekProvider(
        keyStore: _KeyStore('key'),
        transport:
            ({
              required uri,
              required headers,
              required body,
              required connectionTimeout,
              required requestTimeout,
              required token,
            }) async {
              sent = jsonDecode(body) as Map<String, dynamic>;
              return DeepSeekHttpResponse(
                statusCode: 200,
                body: _toolResponse({
                  'action': 'queryAttendance',
                  'employeeText': 'E001',
                  'year': 2025,
                  'yearReference': 'explicit',
                  'month': 9,
                  'clarification': null,
                }),
              );
            },
      );
      const input = '查编号E001在2025年9月的考勤';

      final intent = await provider.parseIntent(
        IntentRequest(text: input, now: DateTime(2026, 10, 18)),
        RequestToken(),
      );

      expect(intent.employeeText, 'E001');
      expect(intent.year, 2025);
      expect(intent.month, 9);
      final messages = sent!['messages'] as List;
      expect(messages.last['content'], input);
    });

    test('rejects extra tool parameters and illegal months', () async {
      final provider = DeepSeekProvider(
        keyStore: _KeyStore('key'),
        transport:
            ({
              required uri,
              required headers,
              required body,
              required connectionTimeout,
              required requestTimeout,
              required token,
            }) async => DeepSeekHttpResponse(
              statusCode: 200,
              body: _toolResponse({..._validArguments(), 'employeeId': 123}),
            ),
      );

      await expectLater(
        provider.parseIntent(
          IntentRequest(text: '查某人9月', now: DateTime(2026, 10)),
          RequestToken(2),
        ),
        throwsA(
          isA<AssistantProviderException>().having(
            (error) => error.code,
            'code',
            AssistantErrorCode.invalidProviderResponse,
          ),
        ),
      );
    });

    test(
      'rejects a tool response truncated by the output token limit',
      () async {
        final provider = DeepSeekProvider(
          keyStore: _KeyStore('key'),
          transport:
              ({
                required uri,
                required headers,
                required body,
                required connectionTimeout,
                required requestTimeout,
                required token,
              }) async => DeepSeekHttpResponse(
                statusCode: 200,
                body: _toolResponse(_validArguments(), finishReason: 'length'),
              ),
        );

        await expectLater(
          provider.parseIntent(
            IntentRequest(text: '查某人9月', now: DateTime(2026, 10)),
            RequestToken(6),
          ),
          throwsA(
            isA<AssistantProviderException>().having(
              (error) => error.code,
              'code',
              AssistantErrorCode.invalidProviderResponse,
            ),
          ),
        );
      },
    );

    test('rejects a month outside the calendar range', () async {
      Map<String, dynamic>? sent;
      final provider = DeepSeekProvider(
        keyStore: _KeyStore('key'),
        transport:
            ({
              required uri,
              required headers,
              required body,
              required connectionTimeout,
              required requestTimeout,
              required token,
            }) async {
              sent = jsonDecode(body) as Map<String, dynamic>;
              return DeepSeekHttpResponse(
                statusCode: 200,
                body: _toolResponse({..._validArguments(), 'month': 13}),
              );
            },
      );
      await expectLater(
        provider.parseIntent(
          IntentRequest(text: '查张三13月考勤', now: DateTime(2026, 10)),
          RequestToken(8),
        ),
        throwsA(
          isA<AssistantProviderException>().having(
            (error) => error.code,
            'code',
            AssistantErrorCode.invalidProviderResponse,
          ),
        ),
      );
      final messages = sent!['messages'] as List;
      final systemPrompt = messages.first['content'] as String;
      expect(
        systemPrompt,
        contains('preserve that number unchanged in month (for example, 13)'),
      );
      expect(
        systemPrompt,
        contains('do not replace it with null or ask for a month'),
      );
    });

    test(
      'rejects action and entity fields that describe conflicting scopes',
      () async {
        Future<AttendanceIntent> parse(
          Map<String, Object?> arguments, {
          AssistantBusinessType previousBusinessType =
              AssistantBusinessType.attendance,
        }) {
          final provider = DeepSeekProvider(
            keyStore: _KeyStore('key'),
            transport:
                ({
                  required uri,
                  required headers,
                  required body,
                  required connectionTimeout,
                  required requestTimeout,
                  required token,
                }) async => DeepSeekHttpResponse(
                  statusCode: 200,
                  body: _toolResponse(arguments),
                ),
          );
          return provider.parseIntent(
            IntentRequest(
              text: '测试意图',
              now: DateTime(2026, 10, 18),
              previousBusinessType: previousBusinessType,
            ),
            RequestToken(),
          );
        }

        final invalidCases = [
          (
            'attendance cannot carry vehicle fields',
            _validArguments()..['vehicleText'] = '一号车',
            AssistantBusinessType.attendance,
          ),
          (
            'attendance cannot become ranking via allVehicles',
            _validArguments()..['allVehicles'] = true,
            AssistantBusinessType.attendance,
          ),
          (
            'payroll business cannot also populate attendance employeeText',
            {
              ..._validArguments(),
              'action': 'queryBusiness',
              'businessType': 'payroll',
              'employeeText': '张三',
              'year': 2026,
              'yearReference': 'explicit',
              'month': 10,
            },
            AssistantBusinessType.attendance,
          ),
          (
            'payroll business cannot also populate vehicleText',
            {
              ..._validArguments(),
              'action': 'queryBusiness',
              'businessType': 'payroll',
              'employeeText': null,
              'vehicleText': '一号车',
              'year': 2026,
              'yearReference': 'explicit',
              'month': 10,
            },
            AssistantBusinessType.attendance,
          ),
          (
            'payroll business cannot request all vehicles',
            {
              ..._validArguments(),
              'action': 'queryBusiness',
              'businessType': 'payroll',
              'employeeText': null,
              'allVehicles': true,
              'year': 2026,
              'yearReference': 'explicit',
              'month': 10,
            },
            AssistantBusinessType.attendance,
          ),
          (
            'single vehicle cannot carry an employee',
            {
              ..._validArguments(),
              'action': 'queryVehicleAnnualRepair',
              'employeeText': '张三',
              'month': null,
              'vehicleText': '一号车',
            },
            AssistantBusinessType.attendance,
          ),
          (
            'single vehicle cannot carry a month',
            {
              ..._validArguments(),
              'action': 'queryVehicleAnnualRepair',
              'employeeText': null,
              'month': 9,
              'vehicleText': '一号车',
            },
            AssistantBusinessType.attendance,
          ),
          (
            'single vehicle cannot become ranking via allVehicles',
            {
              ..._validArguments(),
              'action': 'queryVehicleAnnualRepair',
              'employeeText': null,
              'vehicleText': '一号车',
              'month': null,
              'allVehicles': true,
            },
            AssistantBusinessType.attendance,
          ),
          (
            'ranking requires allVehicles and no specific entity',
            {
              ..._validArguments(),
              'action': 'queryVehicleAnnualRanking',
              'employeeText': null,
              'vehicleText': null,
              'month': null,
              'allVehicles': false,
            },
            AssistantBusinessType.attendance,
          ),
          (
            'ranking cannot carry a vehicle name',
            {
              ..._validArguments(),
              'action': 'queryVehicleAnnualRanking',
              'employeeText': null,
              'vehicleText': '一号车',
              'month': null,
              'allVehicles': true,
            },
            AssistantBusinessType.attendance,
          ),
          (
            'changeYear keeps current attendance business',
            {
              ..._validArguments(),
              'action': 'changeYear',
              'vehicleText': '一号车',
            },
            AssistantBusinessType.attendance,
          ),
          (
            'changeYear keeps current single-vehicle business',
            {
              ..._validArguments(),
              'action': 'changeYear',
              'employeeText': '张三',
              'month': null,
            },
            AssistantBusinessType.vehicleAnnualRepair,
          ),
          (
            'changeYear cannot switch ranking into a vehicle query',
            {
              ..._validArguments(),
              'action': 'changeYear',
              'employeeText': null,
              'vehicleText': '一号车',
              'month': null,
              'allVehicles': false,
            },
            AssistantBusinessType.vehicleAnnualRanking,
          ),
          (
            'changeYear cannot switch attendance into ranking',
            {..._validArguments(), 'action': 'changeYear', 'allVehicles': true},
            AssistantBusinessType.attendance,
          ),
        ];

        for (final invalidCase in invalidCases) {
          await expectLater(
            parse(invalidCase.$2, previousBusinessType: invalidCase.$3),
            throwsA(
              isA<AssistantProviderException>().having(
                (error) => error.code,
                'code',
                AssistantErrorCode.invalidProviderResponse,
              ),
            ),
            reason: invalidCase.$1,
          );
        }
      },
    );

    test(
      'accepts missing-scope follow-ups and valid vehicle query scopes',
      () async {
        Future<AttendanceIntent> parse(
          Map<String, Object?> arguments, {
          AssistantBusinessType previousBusinessType =
              AssistantBusinessType.attendance,
        }) =>
            DeepSeekProvider(
              keyStore: _KeyStore('key'),
              transport:
                  ({
                    required uri,
                    required headers,
                    required body,
                    required connectionTimeout,
                    required requestTimeout,
                    required token,
                  }) async => DeepSeekHttpResponse(
                    statusCode: 200,
                    body: _toolResponse(arguments),
                  ),
            ).parseIntent(
              IntentRequest(
                text: '测试意图',
                now: DateTime(2026, 10, 18),
                previousBusinessType: previousBusinessType,
              ),
              RequestToken(),
            );

        final clarification = await parse({
          'action': 'clarify',
          'employeeText': null,
          'year': null,
          'yearReference': 'unspecified',
          'month': null,
          'clarification': '要查哪辆车？',
        });
        final singleVehicle = await parse({
          ..._validArguments(),
          'action': 'queryVehicleAnnualRepair',
          'employeeText': null,
          'vehicleText': '一号车',
          'month': null,
        });
        final ranking = await parse({
          ..._validArguments(),
          'action': 'queryVehicleAnnualRanking',
          'employeeText': null,
          'vehicleText': null,
          'month': null,
          'allVehicles': true,
        });
        final rankingYearChange = await parse({
          ..._validArguments(),
          'action': 'changeYear',
          'employeeText': null,
          'month': null,
          'year': null,
          'yearReference': 'previous',
        }, previousBusinessType: AssistantBusinessType.vehicleAnnualRanking);
        final singleVehicleFromRanking = await parse({
          ..._validArguments(),
          'action': 'queryVehicleAnnualRepair',
          'employeeText': null,
          'month': null,
          'vehicleText': 'V03',
          'year': null,
          'yearReference': 'previous',
        }, previousBusinessType: AssistantBusinessType.vehicleAnnualRanking);
        final currentYearForVehicle = await parse({
          ..._validArguments(),
          'action': 'changeYear',
          'employeeText': null,
          'month': null,
          'vehicleText': null,
          'allVehicles': false,
          'year': null,
          'yearReference': 'current',
        }, previousBusinessType: AssistantBusinessType.vehicleAnnualRepair);

        expect(clarification.action, AttendanceAction.clarify);
        expect(singleVehicle.vehicleText, '一号车');
        expect(ranking.allVehicles, isTrue);
        expect(rankingYearChange.action, AttendanceAction.changeYear);
        expect(
          singleVehicleFromRanking.action,
          AttendanceAction.queryVehicleAnnualRepair,
        );
        expect(singleVehicleFromRanking.vehicleText, 'V03');
        expect(currentYearForVehicle.action, AttendanceAction.changeYear);
        expect(currentYearForVehicle.yearReference, YearReference.current);
      },
    );

    test(
      'prompt uses the complete valid object for unsupported requests',
      () async {
        Map<String, dynamic>? sent;
        final provider = DeepSeekProvider(
          keyStore: _KeyStore('key'),
          transport:
              ({
                required uri,
                required headers,
                required body,
                required connectionTimeout,
                required requestTimeout,
                required token,
              }) async {
                sent = jsonDecode(body) as Map<String, dynamic>;
                return DeepSeekHttpResponse(
                  statusCode: 200,
                  body: _toolResponse({
                    'action': 'unsupported',
                    'employeeText': null,
                    'year': null,
                    'yearReference': 'unspecified',
                    'month': null,
                    'clarification': null,
                  }),
                );
              },
        );

        final intent = await provider.parseIntent(
          IntentRequest(text: '把张三9月考勤改为全勤', now: DateTime(2026, 10, 18)),
          RequestToken(),
        );

        expect(intent.action, AttendanceAction.unsupported);
        expect(intent.employeeText, isNull);
        expect(intent.year, isNull);
        expect(intent.yearReference, YearReference.unspecified);
        expect(intent.month, isNull);
        expect(intent.clarification, isNull);
        expect(intent.businessType, AssistantBusinessType.attendance);
        expect(intent.businessSubject, isNull);
        expect(intent.businessOperation, 'summary');
        final messages = sent!['messages'] as List;
        final systemPrompt = messages.first['content'] as String;
        final tool = (sent!['tools'] as List).single as Map<String, dynamic>;
        final function = tool['function'] as Map<String, dynamic>;
        final parameters = function['parameters'] as Map<String, dynamic>;
        final requiredKeys = (parameters['required'] as List).cast<String>();
        final unsupportedExample = RegExp(
          r'object: (\{"action":"unsupported".*?\})\.',
        ).firstMatch(systemPrompt);
        expect(unsupportedExample, isNotNull);
        final exampleArguments =
            jsonDecode(unsupportedExample!.group(1)!) as Map<String, dynamic>;
        expect(exampleArguments.keys.toSet(), requiredKeys.toSet());
      },
    );

    test(
      'prompt retains vehicle task scope when the vehicle is omitted',
      () async {
        Map<String, dynamic>? sent;
        final provider = DeepSeekProvider(
          keyStore: _KeyStore('key'),
          transport:
              ({
                required uri,
                required headers,
                required body,
                required connectionTimeout,
                required requestTimeout,
                required token,
              }) async {
                sent = jsonDecode(body) as Map<String, dynamic>;
                return DeepSeekHttpResponse(
                  statusCode: 200,
                  body: _toolResponse({
                    ..._validArguments(),
                    'action': 'queryVehicleAnnualRepair',
                    'employeeText': null,
                    'month': null,
                    'vehicleText': null,
                  }),
                );
              },
        );

        final intent = await provider.parseIntent(
          IntentRequest(text: '查维修费用', now: DateTime(2026, 10, 18)),
          RequestToken(),
        );

        expect(intent.action, AttendanceAction.queryVehicleAnnualRepair);
        expect(intent.vehicleText, isNull);
        expect(intent.employeeText, isNull);
        expect(intent.month, isNull);
        final messages = sent!['messages'] as List;
        final systemPrompt = messages.first['content'] as String;
        expect(
          systemPrompt,
          contains('“查维修费用” is a single-vehicle query with a missing vehicle'),
        );
        expect(
          systemPrompt,
          contains('Do not use clarify merely to ask for a missing person'),
        );
        expect(
          systemPrompt,
          contains(
            'switching from all-vehicle ranking to one named vehicle, use queryVehicleAnnualRepair',
          ),
        );
        expect(
          systemPrompt,
          contains('“查一下V03去年全年的维修费用” is a queryVehicleAnnualRepair request'),
        );
        expect(
          systemPrompt,
          contains('“改看今年的” uses yearReference current, year null'),
        );
      },
    );

    test('monthly overtime summary remains an attendance query', () async {
      Map<String, dynamic>? sent;
      final provider = DeepSeekProvider(
        keyStore: _KeyStore('key'),
        transport:
            ({
              required uri,
              required headers,
              required body,
              required connectionTimeout,
              required requestTimeout,
              required token,
            }) async {
              sent = jsonDecode(body) as Map<String, dynamic>;
              return DeepSeekHttpResponse(
                statusCode: 200,
                body: _toolResponse({
                  'action': 'queryAttendance',
                  'employeeText': '张三',
                  'year': null,
                  'yearReference': 'unspecified',
                  'month': null,
                  'clarification': null,
                }),
              );
            },
      );

      final intent = await provider.parseIntent(
        IntentRequest(text: '张三上月加班时长汇总', now: DateTime(2026, 10, 18)),
        RequestToken(),
      );

      expect(intent.action, AttendanceAction.queryAttendance);
      expect(intent.employeeText, '张三');
      final messages = sent!['messages'] as List;
      final systemPrompt = messages.first['content'] as String;
      expect(
        systemPrompt,
        contains('attendance, leave/rest, or overtime summary for one person'),
      );
      expect(systemPrompt, contains('last month’s overtime duration summary'));
    });

    test(
      'classifies a named business query without inventing a local ID',
      () async {
        Map<String, dynamic>? sent;
        final provider = DeepSeekProvider(
          keyStore: _KeyStore('key'),
          transport:
              ({
                required uri,
                required headers,
                required body,
                required connectionTimeout,
                required requestTimeout,
                required token,
              }) async {
                sent = jsonDecode(body) as Map<String, dynamic>;
                return DeepSeekHttpResponse(
                  statusCode: 200,
                  body: _toolResponse({
                    'action': 'queryBusiness',
                    'employeeText': null,
                    'clarification': null,
                    'year': 2026,
                    'yearReference': 'explicit',
                    'month': 10,
                    'businessType': 'payroll',
                    'businessSubject': '演示员工林晓禾',
                  }),
                );
              },
        );

        final intent = await provider.parseIntent(
          IntentRequest(
            text: '查2026年10月演示员工林晓禾工资',
            now: DateTime(2026, 10, 19),
            previousBusinessType: AssistantBusinessType.payroll,
            previousBusinessYearMonth: '2025-09',
          ),
          RequestToken(),
        );

        expect(intent.action, AttendanceAction.queryBusiness);
        expect(intent.businessType, AssistantBusinessType.payroll);
        expect(intent.businessSubject, '演示员工林晓禾');
        expect(intent.year, 2026);
        expect(intent.yearReference, YearReference.explicit);
        expect(intent.month, 10);
        expect(intent.businessOperation, 'summary');
        final requestContext =
            (sent!['messages'] as List).firstWhere(
                  (message) => message['role'] == 'system',
                )['content']
                as String;
        expect(
          requestContext,
          contains('"previousBusinessYearMonth":"2025-09"'),
        );
        expect(jsonEncode(sent), isNot(contains('inventoryMaterialId')));
        expect(jsonEncode(sent), isNot(contains('employeeId')));
      },
    );

    test(
      'rejects unknown function calls and plain text without retrying',
      () async {
        final invalidResponses = [
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'tool_calls',
                'message': {
                  'tool_calls': [
                    {
                      'function': {
                        'name': 'otherFunction',
                        'arguments': jsonEncode(_validArguments()),
                      },
                    },
                  ],
                },
              },
            ],
          }),
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'content': '王敏本月出勤正常。'},
              },
            ],
          }),
        ];

        for (var i = 0; i < invalidResponses.length; i++) {
          final provider = DeepSeekProvider(
            keyStore: _KeyStore('key'),
            transport:
                ({
                  required uri,
                  required headers,
                  required body,
                  required connectionTimeout,
                  required requestTimeout,
                  required token,
                }) async => DeepSeekHttpResponse(
                  statusCode: 200,
                  body: invalidResponses[i],
                ),
          );
          await expectLater(
            provider.parseIntent(
              IntentRequest(text: '查王敏9月考勤', now: DateTime(2026, 10)),
              RequestToken(20 + i),
            ),
            throwsA(
              isA<AssistantProviderException>().having(
                (error) => error.code,
                'code',
                AssistantErrorCode.invalidProviderResponse,
              ),
            ),
          );
          expect(provider.requestCount, 1);
        }
      },
    );

    test('maps auth, socket, and timeout failures without retrying', () async {
      const expectedCodes = [
        AssistantErrorCode.unauthorized,
        AssistantErrorCode.network,
        AssistantErrorCode.timeout,
      ];

      for (var i = 0; i < expectedCodes.length; i++) {
        final current = i;
        final provider = DeepSeekProvider(
          keyStore: _KeyStore('key'),
          transport:
              ({
                required uri,
                required headers,
                required body,
                required connectionTimeout,
                required requestTimeout,
                required token,
              }) async {
                if (current == 0) {
                  return const DeepSeekHttpResponse(
                    statusCode: 401,
                    body: 'private auth response',
                  );
                }
                if (current == 1) throw const SocketException('offline');
                throw TimeoutException('slow');
              },
        );
        await expectLater(
          provider.parseIntent(
            IntentRequest(text: '查王敏9月考勤', now: DateTime(2026, 10)),
            RequestToken(30 + i),
          ),
          throwsA(
            isA<AssistantProviderException>().having(
              (error) => error.code,
              'code',
              expectedCodes[current],
            ),
          ),
        );
        expect(provider.requestCount, 1);
      }
    });

    test(
      'cancellation invokes the registered transport abort handler',
      () async {
        final token = RequestToken(7);
        final waiting = Completer<DeepSeekHttpResponse>();
        var aborted = false;
        final provider = DeepSeekProvider(
          keyStore: _KeyStore('key'),
          transport:
              ({
                required uri,
                required headers,
                required body,
                required connectionTimeout,
                required requestTimeout,
                required token,
              }) {
                token.addCancelHandler(() {
                  aborted = true;
                  waiting.completeError(const SocketException('cancelled'));
                });
                return waiting.future;
              },
        );
        final future = provider.parseIntent(
          IntentRequest(text: '查某人9月', now: DateTime(2026, 10)),
          token,
        );
        await Future<void>.delayed(Duration.zero);
        token.cancel();

        await expectLater(
          future,
          throwsA(
            isA<AssistantProviderException>().having(
              (error) => error.code,
              'code',
              AssistantErrorCode.cancelled,
            ),
          ),
        );
        expect(aborted, isTrue);
      },
    );

    test('explains only the four-field local summary projection', () async {
      Map<String, dynamic>? sent;
      final provider = DeepSeekProvider(
        keyStore: _KeyStore('key'),
        transport:
            ({
              required uri,
              required headers,
              required body,
              required connectionTimeout,
              required requestTimeout,
              required token,
            }) async {
              sent = jsonDecode(body) as Map<String, dynamic>;
              return const DeepSeekHttpResponse(
                statusCode: 200,
                body: '{"choices":[{"message":{"content":"汇总说明"}}]}',
              );
            },
      );

      final result = await provider.explainSummary(
        const AttendanceOutboundSummary(
          yearMonth: '2026-09',
          attendanceDays: 20,
          leaveAndRestDays: 2,
          overtimeMinutes: 95,
        ),
        RequestToken(3),
      );

      expect(result.text, '汇总说明');
      final messages = sent?['messages'] as List;
      final summary = jsonDecode(messages.last['content'] as String);
      expect(summary, {
        'yearMonth': '2026-09',
        'attendanceDays': 20,
        'leaveAndRestDays': 2,
        'overtimeMinutes': 95,
      });
      expect(summary.keys, hasLength(4));
    });

    test(
      'reports key and rate-limit failures without exposing response body',
      () async {
        final missing = DeepSeekProvider(
          keyStore: _KeyStore(null),
          transport: _unexpectedTransport,
        );
        await expectLater(
          missing.checkConnection(RequestToken(4)),
          throwsA(
            isA<AssistantProviderException>().having(
              (error) => error.code,
              'code',
              AssistantErrorCode.missingApiKey,
            ),
          ),
        );

        final rateLimited = DeepSeekProvider(
          keyStore: _KeyStore('key'),
          transport:
              ({
                required uri,
                required headers,
                required body,
                required connectionTimeout,
                required requestTimeout,
                required token,
              }) async => const DeepSeekHttpResponse(
                statusCode: 429,
                body: 'sensitive raw provider detail',
              ),
        );
        await expectLater(
          rateLimited.checkConnection(RequestToken(5)),
          throwsA(
            isA<AssistantProviderException>()
                .having(
                  (error) => error.code,
                  'code',
                  AssistantErrorCode.rateLimited,
                )
                .having(
                  (error) => error.toString(),
                  'message',
                  isNot(contains('sensitive raw provider detail')),
                ),
          ),
        );
      },
    );
  });
}

Map<String, Object?> _validArguments() => {
  'action': 'queryAttendance',
  'employeeText': '王敏',
  'year': null,
  'yearReference': 'previous',
  'month': 9,
  'clarification': null,
  'vehicleText': null,
  'allVehicles': false,
  'expenseCategory': 'all',
  'expensePeriod': 'recent30Days',
  'expenseYearMonth': null,
  'businessType': 'attendance',
  'businessSubject': null,
  'businessOperation': 'summary',
};

Map<String, Object?> _vehicleExpenseArguments({
  required String period,
  required String? yearMonth,
}) => {
  ..._validArguments(),
  'action': 'queryVehicleExpenseAnalysis',
  'employeeText': null,
  'year': null,
  'yearReference': 'unspecified',
  'month': null,
  'expenseCategory': 'fuel',
  'expensePeriod': period,
  'expenseYearMonth': yearMonth,
};

String _toolResponse(
  Map<String, Object?> arguments, {
  String finishReason = 'tool_calls',
}) => jsonEncode({
  'choices': [
    {
      'finish_reason': finishReason,
      'message': {
        'tool_calls': [
          {
            'function': {
              'name': 'prepareAssistantQuery',
              'arguments': jsonEncode({
                'vehicleText': null,
                'allVehicles': false,
                'expenseCategory': 'all',
                'expensePeriod': 'recent30Days',
                'expenseYearMonth': null,
                'businessType': 'attendance',
                'businessSubject': null,
                'businessOperation': 'summary',
                ...arguments,
              }),
            },
          },
        ],
      },
    },
  ],
  'usage': {'prompt_tokens': 12, 'completion_tokens': 5},
});

String _agentToolResponse({
  required String content,
  required String id,
  required String name,
  required Map<String, Object?> arguments,
  required int promptTokens,
  required int completionTokens,
}) => jsonEncode({
  'choices': [
    {
      'finish_reason': 'tool_calls',
      'message': {
        'content': content,
        'tool_calls': [
          {
            'id': id,
            'type': 'function',
            'function': {'name': name, 'arguments': jsonEncode(arguments)},
          },
        ],
      },
    },
  ],
  'usage': {
    'prompt_tokens': promptTokens,
    'completion_tokens': completionTokens,
  },
});

String _agentTextResponse(
  String content, {
  required int promptTokens,
  required int completionTokens,
}) => jsonEncode({
  'choices': [
    {
      'finish_reason': 'stop',
      'message': {'content': content},
    },
  ],
  'usage': {
    'prompt_tokens': promptTokens,
    'completion_tokens': completionTokens,
  },
});

Future<DeepSeekHttpResponse> _unexpectedTransport({
  required Uri uri,
  required Map<String, String> headers,
  required String body,
  required Duration connectionTimeout,
  required Duration requestTimeout,
  required RequestToken token,
}) async => throw StateError('Transport must not be called.');

class _KeyStore implements AssistantKeyStore {
  _KeyStore(this.key);

  String? key;

  @override
  Future<bool> hasKey() async => key != null;

  @override
  Future<String?> readKey() async => key;

  @override
  Future<void> removeKey() async => key = null;

  @override
  Future<void> saveKey(String key) async => this.key = key;
}
