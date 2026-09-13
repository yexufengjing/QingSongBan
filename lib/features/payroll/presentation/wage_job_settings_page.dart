// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../application/payroll_providers.dart';
import '../data/wage_settings_repository.dart';

class WageJobSettingsPage extends ConsumerWidget {
  const WageJobSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(wageJobTypesProvider);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('工种与日薪设置'),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              tooltip: '新增工种',
            ),
          ],
        ),
        body: types.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('工种加载失败：$error')),
          data: (values) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('日薪按元保存。修改日薪时请使用“生效月份”，已生成或已确认的工资不会被重算。'),
                ),
              ),
              const SizedBox(height: 10),
              for (final type in values) ...[
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(type.name),
                        subtitle: Text(
                          '默认日薪：${type.defaultDailyWage.toStringAsFixed(2)} 元 · ${type.isActive ? '启用' : '已停用'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'edit')
                              await _edit(context, ref, type: type);
                            if (action == 'rate')
                              await _addRate(context, ref, type);
                            if (action == 'disable') {
                              await ref
                                  .read(wageSettingsRepositoryProvider)
                                  .deactivateJobType(type.id);
                              ref.invalidate(wageJobTypesProvider);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('修改工种'),
                            ),
                            const PopupMenuItem(
                              value: 'rate',
                              child: Text('添加生效日薪'),
                            ),
                            if (type.isActive)
                              const PopupMenuItem(
                                value: 'disable',
                                child: Text('停用工种'),
                              ),
                          ],
                        ),
                      ),
                      StreamBuilder<List<WageRateHistoryData>>(
                        stream: ref
                            .read(wageSettingsRepositoryProvider)
                            .watchRates(type.id),
                        builder: (context, snapshot) {
                          final rates = snapshot.data ?? const [];
                          if (rates.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '生效历史：${rates.map((rate) => '${rate.effectiveMonth}=${rate.dailyWage.toStringAsFixed(2)}元').join(' · ')}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (values.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('尚未配置工种')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    WageJobType? type,
  }) async {
    final name = TextEditingController(text: type?.name ?? '');
    final wage = TextEditingController(
      text: type?.defaultDailyWage.toStringAsFixed(2) ?? '0',
    );
    final remark = TextEditingController(text: type?.remark ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == null ? '新增工种' : '修改工种'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '工种名称'),
            ),
            TextField(
              controller: wage,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '默认日薪（元）'),
            ),
            TextField(
              controller: remark,
              decoration: const InputDecoration(labelText: '备注'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) {
      try {
        await ref
            .read(wageSettingsRepositoryProvider)
            .saveJobType(
              id: type?.id,
              draft: WageJobTypeDraft(
                name: name.text,
                defaultDailyWage: double.tryParse(wage.text) ?? double.nan,
                remark: remark.text,
              ),
            );
        ref.invalidate(wageJobTypesProvider);
      } catch (error) {
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
    name.dispose();
    wage.dispose();
    remark.dispose();
  }

  Future<void> _addRate(
    BuildContext context,
    WidgetRef ref,
    WageJobType type,
  ) async {
    final wage = TextEditingController(
      text: type.defaultDailyWage.toStringAsFixed(2),
    );
    final month = TextEditingController(text: payrollYearMonth(DateTime.now()));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${type.name} 生效日薪'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: month,
              decoration: const InputDecoration(labelText: '生效月份（YYYY-MM）'),
            ),
            TextField(
              controller: wage,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '日薪（元）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) {
      try {
        await ref
            .read(wageSettingsRepositoryProvider)
            .saveRate(
              WageRateDraft(
                jobTypeId: type.id,
                dailyWage: double.tryParse(wage.text) ?? double.nan,
                effectiveMonth: month.text,
              ),
            );
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('生效日薪已保存')));
      } catch (error) {
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
    wage.dispose();
    month.dispose();
  }
}
