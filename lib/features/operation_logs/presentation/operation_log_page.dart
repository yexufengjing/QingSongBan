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
      appBar: AppBar(title: const Text('操作日志'), centerTitle: true),
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('日志加载失败：$error')),
        data: (items) => items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: AppColors.lightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_edu_outlined,
                          size: 48,
                          color: AppColors.helper,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '暂无操作日志',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '执行操作后，会在这里生成记录。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.body, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
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
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: OutlinedButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('返回我的'),
        ),
      ),
    );
  }
}
