import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../application/assistant_providers.dart';
import '../domain/assistant_models.dart';

class AssistantSettingsPage extends ConsumerStatefulWidget {
  const AssistantSettingsPage({super.key});

  @override
  ConsumerState<AssistantSettingsPage> createState() =>
      _AssistantSettingsPageState();
}

class _AssistantSettingsPageState extends ConsumerState<AssistantSettingsPage> {
  final _keyController = TextEditingController();
  late Future<bool> _hasKey;
  var _busy = false;
  String? _status;
  bool? _statusSuccess;

  @override
  void initState() {
    super.initState();
    _hasKey = ref.read(assistantKeyStoreProvider).hasKey();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await ref.read(assistantKeyStoreProvider).saveKey(_keyController.text);
      ref.invalidate(assistantKeyConfiguredProvider);
      _keyController.clear();
      _hasKey = Future.value(true);
      _setStatus('Key 已安全保存。', success: true);
    } on ArgumentError {
      _setStatus('请输入 API Key。', success: false);
    } catch (_) {
      _setStatus('保存失败，请稍后重试。', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await ref.read(assistantKeyStoreProvider).removeKey();
      ref.invalidate(assistantKeyConfiguredProvider);
      _keyController.clear();
      _hasKey = Future.value(false);
      _setStatus('DeepSeek API Key 已移除。', success: true);
    } catch (_) {
      _setStatus('移除失败，请稍后重试。', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkConnection() async {
    setState(() {
      _busy = true;
      _status = '正在发起连接测试…';
      _statusSuccess = null;
    });
    try {
      final result = await ref
          .read(deepSeekProvider)
          .checkConnection(RequestToken());
      _setStatus(
        result.success ? '连接测试成功。' : '连接测试失败。',
        success: result.success,
      );
    } on AssistantProviderException catch (error) {
      _setStatus(_providerErrorText(error), success: false);
    } catch (_) {
      _setStatus('连接测试失败，请检查网络后重试。', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setStatus(String text, {required bool success}) {
    if (!mounted) return;
    setState(() {
      _status = text;
      _statusSuccess = success;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('智能助手设置')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DeepSeek API Key',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                FutureBuilder<bool>(
                  future: _hasKey,
                  builder: (context, snapshot) => Text(
                    snapshot.data == true ? '当前已配置：••••••••' : '当前未配置',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: snapshot.data == true
                          ? AppColors.success
                          : AppColors.body,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _keyController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '粘贴 API Key',
                    hintText: '输入后保存；已保存的 Key 不会回显',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _checkConnection,
                      icon: const Icon(Icons.network_check_outlined),
                      label: const Text('测试连接'),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _remove,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('移除 Key'),
                    ),
                  ],
                ),
                if (_status != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _status!,
                    style: TextStyle(
                      color: _statusSuccess == null
                          ? AppColors.body
                          : _statusSuccess!
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '仅在你主动提交问题或点击“测试连接”时才会请求 DeepSeek。'
              '点击测试连接会发送一次真实请求，可能产生费用。'
              '用户提交的文本会发送给 DeepSeek；App 不会自动附加本地姓名、候选或明细。'
              'API Key 只保存在 Android 安全存储，不会放入聊天记录、数据库或备份。',
            ),
          ),
        ),
      ],
    ),
  );
}

String _providerErrorText(AssistantProviderException error) {
  switch (error.httpStatus) {
    case 401:
      return 'DeepSeek 认证失败（HTTP 401）。请在官方平台新建 API Key，重新粘贴并保存后测试。';
    case 402:
      return 'DeepSeek API 余额不足（HTTP 402）。请检查官方平台的 API 账户余额。';
    case 403:
      return '访问被拒绝（HTTP 403）。暂不能判定 Key 无效；请切换手机网络后重试，并检查平台账户的访问权限。';
  }
  return switch (error.code) {
    AssistantErrorCode.missingApiKey => '尚未配置 DeepSeek API Key。',
    AssistantErrorCode.unauthorized => 'API Key 无效或无权访问该模型。',
    AssistantErrorCode.rateLimited => '请求过于频繁，请稍后重试。',
    AssistantErrorCode.timeout => '连接超时，请检查网络后重试。',
    AssistantErrorCode.network => '网络连接失败，请检查网络后重试。',
    AssistantErrorCode.invalidProviderResponse => 'DeepSeek 返回内容无法读取。',
    AssistantErrorCode.providerUnavailable => 'DeepSeek 服务暂时不可用。',
    AssistantErrorCode.cancelled => '已停止本次请求。',
    _ => '连接测试失败，请检查配置后重试。',
  };
}
