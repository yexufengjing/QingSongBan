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
                            if (action == 'enable') {
                              await ref
                                  .read(wageSettingsRepositoryProvider)
                                  .activateJobType(type.id);
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
                            if (!type.isActive)
                              const PopupMenuItem(
                                value: 'enable',
                                child: Text('启用工种'),
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
      builder: (context) {
        var isActive = type?.isActive ?? true;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            title: Row(
              children: [
                Icon(
                  type == null ? Icons.add_business_outlined : Icons.edit_note,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(type == null ? '新增工种' : '修改工种')),
              ],
            ),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      type == null
                          ? '设置工种名称和默认日薪，后续可再添加分月生效的日薪。'
                          : '修改只影响后续新建或生成的工资批次，已生成工资保留原快照。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '工种名称',
                        hintText: '例如：夜班保洁',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: wage,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '默认日薪（元）',
                        hintText: '请输入大于等于 0 的金额',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          title: const Text('启用工种'),
                          subtitle: Text(
                            isActive ? '可用于新工资资料和造资' : '停用后不再用于新的工资资料',
                          ),
                          value: isActive,
                          onChanged: (value) =>
                              setState(() => isActive = value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: remark,
                      textInputAction: TextInputAction.done,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '备注（可选）',
                        hintText: '补充适用范围或说明',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(isActive),
                icon: const Icon(Icons.check),
                label: const Text('保存工种'),
              ),
            ],
          ),
        );
      },
    );
    if (saved != null) {
      try {
        await ref
            .read(wageSettingsRepositoryProvider)
            .saveJobType(
              id: type?.id,
              draft: WageJobTypeDraft(
                name: name.text,
                defaultDailyWage: double.tryParse(wage.text) ?? double.nan,
                isActive: saved,
                sortOrder: type?.sortOrder ?? 0,
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        title: Row(
          children: [
            Icon(
              Icons.event_repeat_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('${type.name} 生效日薪')),
          ],
        ),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '设置从某个月开始执行的日薪。同一工种同一月份重复保存会更新原记录。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: month,
                  readOnly: true,
                  onTap: () => _pickEffectiveMonth(context, month),
                  decoration: InputDecoration(
                    labelText: '生效月份',
                    hintText: '点击选择月份',
                    helperText: '按月生效，不区分具体日期',
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                    suffixIcon: IconButton(
                      onPressed: () => _pickEffectiveMonth(context, month),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      tooltip: '选择月份',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: wage,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '日薪（元）',
                    hintText: '请输入大于等于 0 的金额',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('保存日薪'),
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
  }

  Future<void> _pickEffectiveMonth(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        var year = now.year;
        var month = now.month;
        final years = [
          for (var value = now.year - 10; value <= now.year + 10; value++)
            value,
        ];
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            title: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('选择生效月份')),
              ],
            ),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '选择从哪一年哪一月开始执行，不需要选择具体日期。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: year,
                          decoration: const InputDecoration(labelText: '年份'),
                          items: [
                            for (final value in years)
                              DropdownMenuItem(
                                value: value,
                                child: Text('$value年'),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => year = value ?? year),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: '月份'),
                          child: Text(
                            '$month月',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var value = 1; value <= 12; value++)
                        ChoiceChip(
                          label: Text('$value月'),
                          selected: month == value,
                          onSelected: (_) => setState(() => month = value),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(DateTime(year, month)),
                icon: const Icon(Icons.check),
                label: const Text('确定月份'),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) controller.text = payrollYearMonth(picked);
  }
}
