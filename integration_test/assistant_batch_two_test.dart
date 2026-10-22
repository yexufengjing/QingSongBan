import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/assistant/application/assistant_chat.dart';
import 'package:qingsongban/features/assistant/application/assistant_providers.dart';
import 'package:qingsongban/features/assistant/data/assistant_chat_repository.dart';
import 'package:qingsongban/features/assistant/domain/assistant_chat_models.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_page.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_chat_settings.dart';

import '../test/assistant/assistant_chat_test.dart' as chat_tests;
import '../test/assistant/deepseek_pricing_test.dart' as pricing_tests;
import '../test/assistant/assistant_chat_view_test.dart' as chat_ui_tests;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Chat contracts on emulator', chat_tests.main);
  group('Pricing on emulator', pricing_tests.main);
  group('Chat widgets on emulator', chat_ui_tests.main);
  testWidgets(
    'emulator: HTTP SSE, modes, drafts, history, stop, missing Key, settings',
    (tester) async {
      final database = AppDatabase.forTesting();
      final repository = DriftAssistantChatRepository(database);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map<String, dynamic>>[];
      server.listen((request) async {
        try {
          final payload = jsonDecode(
            await utf8.decoder.bind(request).join(),
          ) as Map<String, dynamic>;
          requests.add(payload);
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          final slow = (payload['messages'] as List).last['content'] == 'slow';
          for (final text in [
            '## 模拟器验证\n',
            '| 项目 | 状态 |\n| --- | --- |\n| 流式回复 | 正常 |\n',
          ]) {
            request.response.write(
              'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': text},
                  },
                ],
              })}\n\n',
            );
            await request.response.flush();
            await Future<void>.delayed(
              Duration(milliseconds: slow ? 3000 : 80),
            );
          }
          request.response.write(
            'data: {"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":20}}\n\ndata: [DONE]\n\n',
          );
          await request.response.close();
        } catch (error) {
          debugPrint('Local SSE fixture: $error');
          await request.response.close();
        }
      });
      final key = _KeyStore();
      await repository.saveSettings(
        AssistantChatSettings(baseUrl: 'http://127.0.0.1:${server.port}'),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          assistantKeyStoreProvider.overrideWithValue(key),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await server.close(force: true);
        await database.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const AssistantPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('自由对话').first);
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('assistant-chat-input'));
      await tester.enterText(input, '保留草稿');
      await tester.tap(find.text('业务查询'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自由对话').first);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '保留草稿');
      await tester.enterText(input, '用表格回答');
      await tester.tap(find.byTooltip('发送'));
      await _until(
        tester,
        () =>
            !container.read(assistantChatProvider).isStreaming &&
            container.read(assistantChatProvider).messages.length == 2,
      );
      expect(
        container.read(assistantChatProvider).messages.last.completed,
        isTrue,
      );
      expect(container.read(assistantChatProvider).inputTokens, 12);
      expect(requests.single['stream'], isTrue);
      expect(requests.single['messages'].toString(), isNot(contains('工资')));
      expect(find.textContaining('正常'), findsWidgets);
      await tester.tap(find.byTooltip('新对话'));
      await tester.pumpAndSettle();
      expect(container.read(assistantChatProvider).inputTokens, 0);
      await tester.tap(find.byTooltip('对话历史'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '用表格');
      await tester.pumpAndSettle();
      await tester.tap(find.text('用表格回答'));
      await tester.pumpAndSettle();
      expect(container.read(assistantChatProvider).messages.length, 2);
      await tester.enterText(input, 'slow');
      await tester.tap(find.byTooltip('发送'));
      await _until(
        tester,
        () => container.read(assistantChatProvider).isStreaming,
      );
      await tester.tap(find.byTooltip('停止生成'));
      await _until(
        tester,
        () => !container.read(assistantChatProvider).isStreaming,
      );
      expect(container.read(assistantChatProvider).error, contains('停止'));
      key.value = null;
      await tester.enterText(input, '没有 Key');
      await tester.tap(find.byTooltip('发送'));
      await _until(
        tester,
        () =>
            container.read(assistantChatProvider).error?.contains('Key') ==
            true,
      );
      expect(requests.length, lessThanOrEqualTo(2));
      final restored = await repository.loadHistory();
      expect(
        restored.sessions.any(
          (session) => session.messages.any(
            (message) => message.content.contains('流式回复'),
          ),
        ),
        isTrue,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: SingleChildScrollView(child: AssistantChatSettingsPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('自由对话 · 模型连接'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (done()) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
  }
  fail('Timed out waiting for chat state');
}

class _KeyStore implements AssistantKeyStore {
  String? value = 'local-fixture-key';
  @override
  Future<bool> hasKey() async => value != null;
  @override
  Future<String?> readKey() async => value;
  @override
  Future<void> saveKey(String key) async => value = key;
  @override
  Future<void> removeKey() async => value = null;
}
