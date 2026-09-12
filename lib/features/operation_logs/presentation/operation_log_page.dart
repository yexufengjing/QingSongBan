import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/operation_log_providers.dart';

class OperationLogPage extends ConsumerWidget {
  const OperationLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(operationLogsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('操作日志')),
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('日志加载失败：$error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('暂无操作日志'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.history,
                        color: AppColors.helper,
                      ),
                      title: Text('${item.operationType} · ${item.entityType}'),
                      subtitle: Text(
                        '${item.detail ?? '无详细说明'}\n${item.createdAt.toLocal()}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: TextButton.icon(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
        label: const Text('返回我的'),
      ),
    );
  }
}
