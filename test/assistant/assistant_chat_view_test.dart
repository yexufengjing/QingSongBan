import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/features/assistant/application/assistant_chat.dart';
import 'package:qingsongban/features/assistant/domain/assistant_chat_models.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_chat_view.dart';

void main() {
  testWidgets(
    'shows a short free-chat empty state with an independent composer',
    (tester) async {
      final notifier = _FakeAssistantChatNotifier();
      await tester.pumpWidget(_app(notifier));

      expect(find.text('有什么想聊的？'), findsOneWidget);
      expect(find.text('输入一个问题，开始新的对话。'), findsOneWidget);
      expect(find.byKey(const Key('assistant-chat-input')), findsOneWidget);
      expect(find.textContaining('业务记录'), findsNothing);
    },
  );

  testWidgets(
    'free chat exposes thinking/search switches and keeps them selected',
    (tester) async {
      await tester.pumpWidget(_app(_FakeAssistantChatNotifier()));
      await tester.pumpAndSettle();
      final thinking = find.widgetWithText(FilterChip, '深度思考');
      final search = find.widgetWithText(FilterChip, '联网搜索');
      await tester.tap(thinking);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(thinking).selected, isTrue);
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(search).selected, isTrue);
    },
  );

  testWidgets('reasoning and authoritative source metadata can be expanded', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ReasoningChatNotifier()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('思考过程'));
    await tester.pumpAndSettle();
    expect(find.text('先核对来源再回答。'), findsOneWidget);
    await tester.ensureVisible(find.text('联网来源 · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('联网来源 · 1'));
    await tester.pumpAndSettle();
    expect(find.text('[1] 官方来源'), findsOneWidget);
  });

  testWidgets(
    'streaming controls fit a narrow screen with keyboard and large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _appWithHome(
          _StreamingChatNotifier(),
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              viewInsets: EdgeInsets.only(bottom: 300),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              appBar: AppBar(title: const Text('智能助手')),
              body: const AssistantChatView(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byTooltip('停止生成'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('sends the composer draft and renders assistant Markdown', (
    tester,
  ) async {
    final notifier = _FakeAssistantChatNotifier();
    await tester.pumpWidget(_app(notifier));

    await tester.enterText(
      find.byKey(const Key('assistant-chat-input')),
      '解释一下这个问题',
    );
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(notifier.sent, ['解释一下这个问题']);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('assistant-chat-input')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.text('解释一下这个问题'), findsOneWidget);
    expect(find.textContaining('回答'), findsOneWidget);
    expect(find.byTooltip('复制消息'), findsNWidgets(2));
  });

  testWidgets('preserves the free-chat draft after the view is unmounted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWithHome(_FakeAssistantChatNotifier(), const _ChatMountHarness()),
    );

    await tester.enterText(
      find.byKey(const Key('assistant-chat-input')),
      '跨页面后继续输入',
    );
    await tester.tap(find.text('卸载自由聊天'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-chat-input')), findsNothing);

    await tester.tap(find.text('重新打开自由聊天'));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(
      find.byKey(const Key('assistant-chat-input')),
    );
    expect(input.controller?.text, '跨页面后继续输入');
  });
}

Widget _app(_FakeAssistantChatNotifier notifier) =>
    _appWithHome(notifier, const Scaffold(body: AssistantChatView()));

Widget _appWithHome(_FakeAssistantChatNotifier notifier, Widget home) =>
    ProviderScope(
      overrides: [
        assistantChatProvider.overrideWith(() => notifier),
        assistantChatSettingsProvider.overrideWith(
          _FakeAssistantChatSettingsNotifier.new,
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

class _ChatMountHarness extends StatefulWidget {
  const _ChatMountHarness();

  @override
  State<_ChatMountHarness> createState() => _ChatMountHarnessState();
}

class _ChatMountHarnessState extends State<_ChatMountHarness> {
  var _showChat = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () => setState(() => _showChat = !_showChat),
          child: Text(_showChat ? '卸载自由聊天' : '重新打开自由聊天'),
        ),
        if (_showChat) const Expanded(child: AssistantChatView()),
      ],
    ),
  );
}

class _FakeAssistantChatNotifier extends AssistantChatNotifier {
  final sent = <String>[];

  @override
  AssistantChatState build() => AssistantChatState();

  @override
  Future<void> send(String text) async {
    sent.add(text);
    state = AssistantChatState(
      sessions: [
        AssistantChatSession(
          id: 'test-session',
          title: text,
          updatedAt: DateTime(2026, 10, 22),
          messages: [
            AssistantChatMessage(role: 'user', content: text),
            const AssistantChatMessage(
              role: 'assistant',
              content: '**回答** 已整理。',
            ),
          ],
        ),
      ],
      currentSessionId: 'test-session',
      messages: [
        AssistantChatMessage(role: 'user', content: text),
        const AssistantChatMessage(role: 'assistant', content: '**回答** 已整理。'),
      ],
    );
  }
}

class _FakeAssistantChatSettingsNotifier extends AssistantChatSettingsNotifier {
  @override
  Future<AssistantChatSettings> build() async => const AssistantChatSettings();
  @override
  Future<void> saveSettings(AssistantChatSettings settings) async {
    state = AsyncData(settings);
  }
}

class _ReasoningChatNotifier extends _FakeAssistantChatNotifier {
  @override
  AssistantChatState build() => AssistantChatState(
    messages: const [
      AssistantChatMessage(
        role: 'assistant',
        content: '根据来源回答。[1]',
        reasoningContent: '先核对来源再回答。',
        searchPerformed: true,
        searchSources: [
          AssistantSearchSource(
            title: '官方来源',
            url: 'https://example.com/source',
            snippet: '来源摘要',
          ),
        ],
      ),
    ],
  );
}

class _StreamingChatNotifier extends _FakeAssistantChatNotifier {
  @override
  AssistantChatState build() => AssistantChatState(
    isStreaming: true,
    inputTokens: 12345,
    outputTokens: 67890,
    messages: const [
      AssistantChatMessage(
        role: 'assistant',
        content: '正在回复',
        reasoningContent: '思考内容',
        completed: false,
      ),
    ],
  );
  @override
  void stop() {}
}
