import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/assistant_chat.dart';
import '../application/assistant_favorites.dart';
import '../domain/assistant_chat_models.dart';
import '../domain/assistant_models.dart';
import '../data/deepseek_chat_provider.dart';
import '../data/deepseek_search_provider.dart';

class AssistantChatSettingsPanel extends ConsumerWidget {
  const AssistantChatSettingsPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(assistantChatSettingsProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(assistantChatSettingsProvider),
          child: const Text('对话设置加载失败，点击重试'),
        ),
        data: (settings) => _ChatSettingsForm(
          key: ValueKey(settings.toJson().toString()),
          settings: settings,
        ),
      );
}

class _ChatSettingsForm extends ConsumerStatefulWidget {
  const _ChatSettingsForm({super.key, required this.settings});
  final AssistantChatSettings settings;
  @override
  ConsumerState<_ChatSettingsForm> createState() => _ChatSettingsFormState();
}

class _ChatSettingsFormState extends ConsumerState<_ChatSettingsForm> {
  late final TextEditingController _url = TextEditingController(
    text: widget.settings.baseUrl,
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.settings.model,
  );
  late AssistantChatSettings _settings = widget.settings;
  bool _busy = false;
  String? _status;
  RequestToken? _token;
  @override
  void dispose() {
    _token?.cancel();
    _url.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        _model.text.trim().isEmpty) {
      setState(() => _status = '请输入有效的 HTTPS API 地址和模型名称。');
      return;
    }
    final proposed = _settings.copyWith(
      baseUrl: _url.text.trim(),
      model: _model.text.trim(),
    );
    if ((proposed.thinkingEnabled && !supportsDeepSeekThinking(proposed)) ||
        (proposed.searchEnabled && !supportsDeepSeekSearch(proposed))) {
      setState(() => _status = '深度思考和联网搜索需使用官方 DeepSeek 地址与支持的模型；请关闭功能或调整连接。');
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await ref
          .read(assistantChatSettingsProvider.notifier)
          .saveSettings(
            _settings.copyWith(
              baseUrl: _url.text.trim(),
              model: _model.text.trim(),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('自由对话设置已保存')));
      }
    } catch (_) {
      if (mounted) setState(() => _status = '保存失败，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _status = '正在测试已保存的自由对话配置…';
    });
    _token = RequestToken();
    try {
      await ref
          .read(deepSeekChatProvider)
          .checkConnection(widget.settings, _token!);
      if (mounted) setState(() => _status = '自由对话连接成功。');
    } catch (e) {
      if (mounted) setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '自由对话 · 模型连接',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('与业务查询独立配置，共用上方安全保存的 Key。仅发送你输入的聊天内容。'),
              ),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  helperText: '默认 DeepSeek；自定义地址将接收聊天内容和 Key',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _model,
                decoration: const InputDecoration(
                  labelText: '模型名称',
                  helperText: '例如 deepseek-flash / deepseek-v4-pro',
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('对话偏好'),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('默认打开自由对话'),
                    value: _settings.defaultFreeChat,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(defaultFreeChat: v),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('深度思考'),
                    subtitle: const Text('适合复杂分析；思考 token 也计入输出用量。'),
                    value: _settings.thinkingEnabled,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(thinkingEnabled: v),
                    ),
                  ),
                  if (_settings.thinkingEnabled)
                    DropdownButtonFormField<String>(
                      initialValue: _settings.reasoningEffort,
                      decoration: const InputDecoration(labelText: '思考强度'),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('轻度')),
                        DropdownMenuItem(value: 'high', child: Text('深入')),
                        DropdownMenuItem(value: 'max', child: Text('最深入')),
                      ],
                      onChanged: (v) => setState(
                        () =>
                            _settings = _settings.copyWith(reasoningEffort: v),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('联网搜索'),
                    subtitle: const Text(
                      '每次发送先搜索当前问题，再结合来源回答。搜索单独计费：2026-11-01 起每千次成功请求 \$0.75。',
                    ),
                    value: _settings.searchEnabled,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(searchEnabled: v),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('回答简洁'),
                    value: _settings.concise,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(concise: v),
                    ),
                  ),
                  DropdownButtonFormField<double>(
                    initialValue: _settings.fontScale,
                    decoration: const InputDecoration(labelText: '对话字号'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('标准')),
                      DropdownMenuItem(value: 1.15, child: Text('较大')),
                      DropdownMenuItem(value: 1.3, child: Text('大')),
                    ],
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(fontScale: v),
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('高级参数'),
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _settings.contextTurns,
                    decoration: const InputDecoration(labelText: '携带最近对话轮数'),
                    items: [
                      for (final n in [4, 8, 12, 20])
                        DropdownMenuItem(value: n, child: Text('$n 轮')),
                    ],
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(contextTurns: v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _settings.maxTokens,
                    decoration: const InputDecoration(
                      labelText: '单次输出 Token 上限',
                    ),
                    items: [
                      for (final n in [1024, 2048, 4096, 8192])
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(maxTokens: v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('保存对话设置'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _test,
                    child: const Text('测试自由对话连接'),
                  ),
                ],
              ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_status!),
                ),
            ],
          ),
        ),
      ),
      Card(
        child: ExpansionTile(
          leading: const Icon(Icons.star_outline),
          title: const Text('管理快捷查询收藏'),
          children: [
            ref
                .watch(assistantQueryFavoritesProvider)
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const ListTile(title: Text('收藏加载失败')),
                  data: (items) => Column(
                    children: [
                      if (items.isEmpty)
                        const ListTile(title: Text('暂无收藏，在快捷查询条件中点击“收藏查询”。')),
                      for (final item in items)
                        ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.query.title),
                          trailing: IconButton(
                            tooltip: '删除收藏',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await ref
                                    .read(
                                      assistantQueryFavoritesProvider.notifier,
                                    )
                                    .remove(item.id);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('删除失败，请重试')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.history),
          title: const Text('自由对话历史'),
          subtitle: const Text('在自由对话顶部打开历史，可搜索、导出或删除会话。记录仅保存在本机。'),
        ),
      ),
    ],
  );
}
