import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../application/assistant_chat.dart';
import '../domain/assistant_chat_models.dart';
import '../data/deepseek_search_provider.dart';

final assistantChatDraftProvider = StateProvider<String>((ref) => '');

/// A standalone free-chat surface that can be embedded in a page or overlay.
class AssistantChatView extends ConsumerStatefulWidget {
  const AssistantChatView({super.key});

  @override
  ConsumerState<AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends ConsumerState<AssistantChatView>
    with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _historySearchController = TextEditingController();
  bool _followOutput = true;

  @override
  void initState() {
    super.initState();
    _inputController.text = ref.read(assistantChatDraftProvider);
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        ref.read(assistantChatProvider).isStreaming) {
      ref.read(assistantChatProvider.notifier).stop();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _followOutput =
        _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <
        72;
  }

  void _scrollToLatest({bool force = false}) {
    if (!mounted || (!force && !_followOutput)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    ref.read(assistantChatDraftProvider.notifier).state = '';
    _followOutput = true;
    await ref.read(assistantChatProvider.notifier).send(text);
    _scrollToLatest();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _editAndResend(int index, String text) async {
    final controller = TextEditingController(text: text);
    final replacement = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑并重新发送'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 8,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(labelText: '消息内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('重新发送'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (replacement == null || replacement.trim().isEmpty || !mounted) return;
    _followOutput = true;
    await ref
        .read(assistantChatProvider.notifier)
        .editAndResend(index, replacement.trim());
    _scrollToLatest();
  }

  Future<void> _exportCurrent(AssistantChatState state) async {
    if (state.messages.isEmpty) return;
    final session = _currentSession(state);
    final content = _sessionMarkdown(session?.title ?? '自由对话', state.messages);
    await _saveMarkdown(content, _safeFileName(session?.title ?? '自由对话'));
  }

  Future<void> _exportHistory(AssistantChatState state) async {
    if (state.sessions.isEmpty) return;
    final content = state.sessions
        .map((session) => _sessionMarkdown(session.title, session.messages))
        .join('\n\n---\n\n');
    await _saveMarkdown(content, '自由对话历史');
  }

  Future<void> _saveMarkdown(String content, String name) async {
    try {
      await FilePicker.saveFile(
        dialogTitle: '导出 Markdown',
        fileName: '$name.md',
        type: FileType.custom,
        allowedExtensions: const ['md'],
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$error')));
    }
  }

  AssistantChatSession? _currentSession(AssistantChatState state) {
    for (final session in state.sessions) {
      if (session.id == state.currentSessionId) return session;
    }
    return null;
  }

  String _sessionMarkdown(String title, List<AssistantChatMessage> messages) {
    final output = StringBuffer('# $title\n');
    for (final message in messages) {
      output
        ..write('\n## ')
        ..write(message.role == 'user' ? '我' : '助手')
        ..write('\n\n')
        ..write(message.content.trim())
        ..write('\n');
      if (message.reasoningContent.isNotEmpty) {
        output.write('\n### 思考过程\n\n${message.reasoningContent}\n');
      }
      if (message.searchSources.isNotEmpty) {
        output.write('\n### 联网来源\n');
        for (var i = 0; i < message.searchSources.length; i++) {
          final source = message.searchSources[i];
          output.write('\n[${i + 1}] ${source.title} — ${source.url}\n');
        }
      }
    }
    return output.toString();
  }

  String _safeFileName(String value) => value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');

  Future<void> _runChatOperation(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      if (!mounted) return;
      final state = ref.read(assistantChatProvider);
      if (state.error?.trim().isNotEmpty != true) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantChatProvider);
    final settings = ref.watch(assistantChatSettingsProvider).valueOrNull;
    ref.listen<AssistantChatState>(assistantChatProvider, (previous, next) {
      if (previous?.messages != next.messages) _scrollToLatest();
    });

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            _ChatToolbar(
              onHistory: _openHistory,
              onNewSession: state.isStreaming
                  ? null
                  : () => _runChatOperation(() async {
                      _inputFocusNode.unfocus();
                      ref.read(assistantChatDraftProvider.notifier).state = '';
                      _inputController.clear();
                      await ref
                          .read(assistantChatProvider.notifier)
                          .newSession();
                      _scrollToLatest(force: true);
                    }),
              onExportCurrent: state.messages.isEmpty
                  ? null
                  : () => _exportCurrent(state),
              onExportHistory: state.sessions.isEmpty
                  ? null
                  : () => _exportHistory(state),
            ),
            if (state.error?.trim().isNotEmpty == true)
              _ChatError(message: state.error!.trim()),
            Expanded(
              child: state.isLoading && state.messages.isEmpty
                  ? const _ChatLoading()
                  : state.messages.isEmpty
                  ? const _ChatEmptyState()
                  : _MessageList(
                      state: state,
                      fontScale: settings?.fontScale ?? 1,
                      controller: _scrollController,
                      onCopy: _copy,
                      onRegenerate: () =>
                          ref.read(assistantChatProvider.notifier).regenerate(),
                      onEdit: _editAndResend,
                    ),
            ),
            if (state.isStreaming)
              _StreamingStatus(
                onStop: () => ref.read(assistantChatProvider.notifier).stop(),
              ),
            if (state.messages.isNotEmpty &&
                (state.inputTokens > 0 ||
                    state.outputTokens > 0 ||
                    state.lastDuration != null))
              _UsageLine(state: state),
            if (settings != null && !state.isStreaming)
              _ChatCapabilities(
                settings: settings,
                busy: state.isStreaming || state.isLoading,
              ),
            _ChatComposer(
              controller: _inputController,
              focusNode: _inputFocusNode,
              onChanged: (value) =>
                  ref.read(assistantChatDraftProvider.notifier).state = value,
              isStreaming: state.isStreaming,
              isLoading: state.isLoading,
              onSend: _send,
              onStop: () => ref.read(assistantChatProvider.notifier).stop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openHistory() async {
    _historySearchController.clear();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(assistantChatProvider);
          final query = _historySearchController.text.trim().toLowerCase();
          final sessions = state.sessions
              .where(
                (session) =>
                    query.isEmpty ||
                    session.title.toLowerCase().contains(query) ||
                    session.messages.any(
                      (message) =>
                          message.content.toLowerCase().contains(query),
                    ),
              )
              .toList(growable: false);
          return FractionallySizedBox(
            heightFactor: .88,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '对话历史',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: '导出全部历史',
                        onPressed: state.sessions.isEmpty
                            ? null
                            : () => _exportHistory(state),
                        icon: const Icon(Icons.file_download_outlined),
                      ),
                      IconButton(
                        tooltip: '清空全部历史',
                        onPressed: state.sessions.isEmpty
                            ? null
                            : () => _confirmClearHistory(sheetContext),
                        icon: const Icon(Icons.delete_sweep_outlined),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _historySearchController,
                    onChanged: (_) => (context as Element).markNeedsBuild(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索标题或对话内容',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: sessions.isEmpty
                      ? Center(
                          child: Text(
                            state.sessions.isEmpty ? '还没有保存的对话' : '没有匹配的对话',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: sessions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final selected =
                                session.id == state.currentSessionId;
                            final preview = session.messages.isEmpty
                                ? '空对话'
                                : session.messages.last.content.trim();
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              selected: selected,
                              selectedTileColor: AppColors.lightBlue,
                              leading: CircleAvatar(
                                backgroundColor: selected
                                    ? AppColors.primary
                                    : AppColors.lightBlue,
                                foregroundColor: selected
                                    ? Colors.white
                                    : AppColors.primary,
                                child: const Icon(
                                  Icons.forum_outlined,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${_formatDate(session.updatedAt)} · $preview',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: '对话操作',
                                onSelected: (action) {
                                  if (action == 'export') {
                                    _saveMarkdown(
                                      _sessionMarkdown(
                                        session.title,
                                        session.messages,
                                      ),
                                      _safeFileName(session.title),
                                    );
                                  } else if (action == 'delete') {
                                    _confirmDelete(sheetContext, session);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'export',
                                    child: Text('导出此对话'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除此对话'),
                                  ),
                                ],
                              ),
                              onTap: state.isStreaming
                                  ? null
                                  : () {
                                      _runChatOperation(
                                        () => ref
                                            .read(
                                              assistantChatProvider.notifier,
                                            )
                                            .openSession(session.id),
                                      );
                                      Navigator.of(sheetContext).pop();
                                      _followOutput = true;
                                      _scrollToLatest(force: true);
                                    },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext sheetContext,
    AssistantChatSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这段对话？'),
        content: Text('“${session.title}”及其中的消息将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runChatOperation(
        () =>
            ref.read(assistantChatProvider.notifier).deleteSession(session.id),
      );
    }
  }

  Future<void> _confirmClearHistory(BuildContext sheetContext) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空全部对话历史？'),
        content: const Text('所有已保存的对话都会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空历史'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(assistantChatDraftProvider.notifier).state = '';
      _inputController.clear();
      await _runChatOperation(
        () => ref.read(assistantChatProvider.notifier).clearHistory(),
      );
      if (mounted && sheetContext.mounted) Navigator.of(sheetContext).pop();
    }
  }
}

class _ChatToolbar extends StatelessWidget {
  const _ChatToolbar({
    required this.onHistory,
    required this.onNewSession,
    required this.onExportCurrent,
    required this.onExportHistory,
  });

  final VoidCallback onHistory;
  final VoidCallback? onNewSession;
  final VoidCallback? onExportCurrent;
  final VoidCallback? onExportHistory;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
    child: Row(
      children: [
        const Icon(
          Icons.auto_awesome_outlined,
          color: AppColors.primary,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '自由对话',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '对话历史',
          onPressed: onHistory,
          icon: const Icon(Icons.history),
        ),
        IconButton(
          tooltip: '新对话',
          onPressed: onNewSession,
          icon: const Icon(Icons.add_comment_outlined),
        ),
        PopupMenuButton<String>(
          tooltip: '导出',
          onSelected: (value) {
            if (value == 'current') onExportCurrent?.call();
            if (value == 'history') onExportHistory?.call();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'current',
              enabled: onExportCurrent != null,
              child: const Text('导出当前对话'),
            ),
            PopupMenuItem(
              value: 'history',
              enabled: onExportHistory != null,
              child: const Text('导出全部历史'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          Text('有什么想聊的？', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '输入一个问题，开始新的对话。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.body),
          ),
        ],
      ),
    ),
  );
}

class _ChatLoading extends StatelessWidget {
  const _ChatLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('正在加载对话…'),
      ],
    ),
  );
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightDanger,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.fontScale,
    required this.controller,
    required this.onCopy,
    required this.onRegenerate,
    required this.onEdit,
  });

  final AssistantChatState state;
  final double fontScale;
  final ScrollController controller;
  final ValueChanged<String> onCopy;
  final VoidCallback onRegenerate;
  final Future<void> Function(int index, String text) onEdit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contentWidth = constraints.maxWidth > 800
          ? 760.0
          : constraints.maxWidth;
      return ListView.builder(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: state.messages.length,
        itemBuilder: (context, index) {
          final message = state.messages[index];
          final isUser = message.role == 'user';
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: _MessageBubble(
                message: message,
                index: index,
                isUser: isUser,
                isLast: index == state.messages.length - 1,
                isStreaming: state.isStreaming,
                fontScale: fontScale,
                onCopy: onCopy,
                onRegenerate: onRegenerate,
                onEdit: onEdit,
              ),
            ),
          );
        },
      );
    },
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.index,
    required this.isUser,
    required this.isLast,
    required this.isStreaming,
    required this.fontScale,
    required this.onCopy,
    required this.onRegenerate,
    required this.onEdit,
  });

  final AssistantChatMessage message;
  final int index;
  final bool isUser;
  final bool isLast;
  final bool isStreaming;
  final double fontScale;
  final ValueChanged<String> onCopy;
  final VoidCallback onRegenerate;
  final Future<void> Function(int index, String text) onEdit;

  @override
  Widget build(BuildContext context) {
    final color = isUser ? AppColors.primary : AppColors.card;
    final theme = Theme.of(context);
    final markdown = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(
        color: isUser ? Colors.white : AppColors.ink,
        fontSize: 16 * fontScale,
        height: 1.5,
      ),
      h1: theme.textTheme.headlineSmall?.copyWith(
        color: isUser ? Colors.white : AppColors.ink,
        fontSize: 24 * fontScale,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        color: isUser ? Colors.white : AppColors.ink,
        fontSize: 20 * fontScale,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        color: isUser ? Colors.white : AppColors.ink,
        fontSize: 17 * fontScale,
      ),
      code: TextStyle(
        color: isUser ? Colors.white : AppColors.ink,
        backgroundColor: isUser ? Colors.white24 : AppColors.background,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: isUser ? Colors.black12 : AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
        color: isUser ? Colors.white12 : AppColors.background,
      ),
      tableBorder: TableBorder.all(color: AppColors.divider),
      tableColumnWidth: const FixedColumnWidth(144),
      tableScrollbarThumbVisibility: true,
    );
    final body = MarkdownBody(
      data: message.content.isEmpty && isLast && isStreaming
          ? '正在生成…'
          : message.content,
      selectable: true,
      softLineBreak: true,
      styleSheet: markdown,
      onTapLink: (_, href, _) {
        if (href != null) _openWebLink(context, href);
      },
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: isUser ? null : Border.all(color: AppColors.divider),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.reasoningContent.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    !message.completed && isLast && isStreaming
                        ? '正在深度思考…'
                        : '思考过程',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SelectableText(
                        message.reasoningContent,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              body,
              if (message.searchPerformed && message.searchSources.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('本轮搜索未找到可用来源，回答仅供参考。'),
                ),
              if (message.searchSources.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('联网来源 · ${message.searchSources.length}'),
                  children: [
                    for (var i = 0; i < message.searchSources.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '[${i + 1}] ${message.searchSources[i].title}',
                        ),
                        subtitle: Text(
                          message.searchSources[i].url,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () =>
                            _openWebLink(context, message.searchSources[i].url),
                      ),
                  ],
                ),
              if (!message.completed && !(isLast && isStreaming))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '回复未完成，可重新生成',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.body,
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '复制消息',
                    visualDensity: VisualDensity.compact,
                    onPressed: message.content.isEmpty
                        ? null
                        : () => onCopy(message.content),
                    icon: Icon(
                      Icons.copy_outlined,
                      size: 18,
                      color: isUser ? Colors.white70 : AppColors.body,
                    ),
                  ),
                  if (isUser)
                    IconButton(
                      tooltip: '编辑并重新发送',
                      visualDensity: VisualDensity.compact,
                      onPressed: isStreaming
                          ? null
                          : () => onEdit(index, message.content),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  if (!isUser && isLast)
                    IconButton(
                      tooltip: '重新生成',
                      visualDensity: VisualDensity.compact,
                      onPressed: isStreaming ? null : onRegenerate,
                      icon: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: AppColors.body,
                      ),
                    ),
                  if (!message.completed && isLast && isStreaming) ...[
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamingStatus extends StatelessWidget {
  const _StreamingStatus({required this.onStop});
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('正在回复…')),
        TextButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('停止'),
        ),
      ],
    ),
  );
}

class _UsageLine extends StatelessWidget {
  const _UsageLine({required this.state});
  final AssistantChatState state;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (state.inputTokens > 0 || state.outputTokens > 0) {
      parts.add('输入 ${state.inputTokens} · 输出 ${state.outputTokens} tokens');
    }
    if (state.lastDuration != null) {
      final duration = state.lastDuration!;
      parts.add(
        duration.inSeconds < 60
            ? '${duration.inSeconds} 秒'
            : '${duration.inMinutes} 分 ${duration.inSeconds % 60} 秒',
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Tooltip(
        message: parts.join('  ·  '),
        child: Text(
          parts.join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.body),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isStreaming,
    required this.isLoading,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isStreaming;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    elevation: 2,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('assistant-chat-input'),
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (!isStreaming && !isLoading) onSend();
              },
              decoration: const InputDecoration(
                hintText: '输入你的问题…',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: isStreaming ? '停止生成' : '发送',
            onPressed: isStreaming
                ? onStop
                : isLoading
                ? null
                : onSend,
            icon: Icon(isStreaming ? Icons.stop : Icons.send_rounded),
          ),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final local = date.toLocal();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return sameDay ? '$hour:$minute' : '$month-$day $hour:$minute';
}

Future<void> _openWebLink(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开该网页')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开该网页')));
    }
  }
}

class _ChatCapabilities extends ConsumerStatefulWidget {
  const _ChatCapabilities({required this.settings, required this.busy});
  final AssistantChatSettings settings;
  final bool busy;
  @override
  ConsumerState<_ChatCapabilities> createState() => _ChatCapabilitiesState();
}

class _ChatCapabilitiesState extends ConsumerState<_ChatCapabilities> {
  bool _saving = false;
  Future<void> _set(AssistantChatSettings settings) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(assistantChatSettingsProvider.notifier)
          .saveSettings(settings);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('功能设置保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 8,
        children: [
          Tooltip(
            message: '复杂问题可开启；思考内容同样消耗输出 token',
            child: FilterChip(
              label: const Text('深度思考'),
              selected: widget.settings.thinkingEnabled,
              backgroundColor: const Color(0xFF475569),
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: widget.settings.thinkingEnabled
                    ? Colors.white
                    : const Color(0xFFCBD5E1),
              ),
              side: BorderSide.none,
              showCheckmark: false,
              avatar: Icon(
                Icons.psychology_outlined,
                size: 18,
                color: widget.settings.thinkingEnabled
                    ? Colors.white
                    : const Color(0xFFCBD5E1),
              ),
              onSelected:
                  widget.busy ||
                      _saving ||
                      (!supportsDeepSeekThinking(widget.settings) &&
                          !widget.settings.thinkingEnabled)
                  ? null
                  : (v) => _set(widget.settings.copyWith(thinkingEnabled: v)),
            ),
          ),
          Tooltip(
            message: '每轮检索问题前 128 个字符；2026-11-01 起搜索单独计费',
            child: FilterChip(
              label: const Text('联网搜索'),
              selected: widget.settings.searchEnabled,
              backgroundColor: const Color(0xFF475569),
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: widget.settings.searchEnabled
                    ? Colors.white
                    : const Color(0xFFCBD5E1),
              ),
              side: BorderSide.none,
              showCheckmark: false,
              avatar: Icon(
                Icons.travel_explore,
                size: 18,
                color: widget.settings.searchEnabled
                    ? Colors.white
                    : const Color(0xFFCBD5E1),
              ),
              onSelected:
                  widget.busy ||
                      _saving ||
                      (!supportsDeepSeekSearch(widget.settings) &&
                          !widget.settings.searchEnabled)
                  ? null
                  : (v) => _set(widget.settings.copyWith(searchEnabled: v)),
            ),
          ),
        ],
      ),
    ),
  );
}
