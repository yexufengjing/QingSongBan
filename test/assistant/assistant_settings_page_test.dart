import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/application/assistant_providers.dart';
import 'package:qingsongban/features/assistant/data/deepseek_provider.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_settings_page.dart';

void main() {
  testWidgets('saves a key without showing it and tests only on tap', (
    tester,
  ) async {
    final keyStore = _MemoryKeyStore();
    var requestCount = 0;
    final requestIds = <int>[];
    final provider = DeepSeekProvider(
      keyStore: keyStore,
      transport:
          ({
            required uri,
            required headers,
            required body,
            required connectionTimeout,
            required requestTimeout,
            required token,
          }) async {
            requestCount++;
            requestIds.add(token.id);
            final responseBody = body.contains('prepareAssistantQuery')
                ? jsonEncode({
                    'choices': [
                      {
                        'finish_reason': 'tool_calls',
                        'message': {
                          'tool_calls': [
                            {
                              'function': {
                                'name': 'prepareAssistantQuery',
                                'arguments': jsonEncode({
                                  'action': 'queryAttendance',
                                  'employeeText': '王敏',
                                  'vehicleText': null,
                                  'allVehicles': false,
                                  'year': null,
                                  'yearReference': 'previous',
                                  'month': 9,
                                  'clarification': null,
                                  'expenseCategory': 'all',
                                  'expensePeriod': 'recent30Days',
                                  'expenseYearMonth': null,
                                  'businessType': 'attendance',
                                  'businessSubject': null,
                                  'businessOperation': 'summary',
                                }),
                              },
                            },
                          ],
                        },
                      },
                    ],
                    'usage': {'prompt_tokens': 12, 'completion_tokens': 5},
                  })
                : '{"choices":[{"message":{"content":"OK"}}]}';
            return DeepSeekHttpResponse(statusCode: 200, body: responseBody);
          },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantKeyStoreProvider.overrideWithValue(keyStore),
          deepSeekProvider.overrideWithValue(provider),
        ],
        child: const MaterialApp(home: AssistantSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(requestCount, 0);

    await tester.enterText(find.byType(TextField), 'sk-sensitive-test');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(await keyStore.readKey(), 'sk-sensitive-test');
    expect(find.text('当前已配置：••••••••'), findsOneWidget);
    expect(find.text('sk-sensitive-test'), findsNothing);
    expect(requestCount, 0);

    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();
    expect(requestCount, 1);
    expect(find.text('连接测试成功。'), findsOneWidget);

    await provider.parseIntent(
      IntentRequest(text: '查王敏去年9月考勤', now: DateTime(2026, 10, 17)),
      RequestToken(),
    );
    expect(requestCount, 2);
    expect(requestIds.toSet(), hasLength(2));
    expect(provider.usageForRequest(requestIds[0]).connectionChecks, 1);
    expect(provider.usageForRequest(requestIds[0]).parseCalls, 0);
    expect(provider.usageForRequest(requestIds[1]).parseCalls, 1);
    expect(provider.usageForRequest(requestIds[1]).connectionChecks, 0);
  });
}

class _MemoryKeyStore implements AssistantKeyStore {
  String? value;

  @override
  Future<bool> hasKey() async => value != null;

  @override
  Future<String?> readKey() async => value;

  @override
  Future<void> removeKey() async => value = null;

  @override
  Future<void> saveKey(String key) async => value = key;
}
