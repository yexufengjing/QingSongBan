import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/application/assistant_providers.dart';
import 'package:qingsongban/features/assistant/data/deepseek_provider.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_settings_page.dart';

void main() {
  for (final status in [401, 402, 403]) {
    testWidgets(
      'connection check distinguishes HTTP $status without exposing response',
      (tester) async {
        final keyStore = _MemoryKeyStore()..value = 'fake-saved-key';
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
                expect(
                  uri.toString(),
                  'https://api.deepseek.com/chat/completions',
                );
                expect(headers['authorization'], 'Bearer fake-saved-key');
                return DeepSeekHttpResponse(
                  statusCode: status,
                  body: 'private-provider-response',
                );
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
        await tester.tap(find.text('测试连接'));
        await tester.pumpAndSettle();
        final expected = switch (status) {
          401 => 'DeepSeek 认证失败（HTTP 401）。请在官方平台新建 API Key，重新粘贴并保存后测试。',
          402 => 'DeepSeek API 余额不足（HTTP 402）。请检查官方平台的 API 账户余额。',
          _ => '访问被拒绝（HTTP 403）。暂不能判定 Key 无效；请切换手机网络后重试，并检查平台账户的访问权限。',
        };
        expect(find.text(expected), findsOneWidget);
        expect(find.textContaining('private-provider-response'), findsNothing);
        expect(find.textContaining('fake-saved-key'), findsNothing);
      },
    );
  }

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

    await tester.enterText(
      find.widgetWithText(TextField, '粘贴 API Key'),
      'sk-sensitive-test',
    );
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
