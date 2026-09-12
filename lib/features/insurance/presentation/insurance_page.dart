import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/insurance_providers.dart';
import '../domain/insurance_options.dart';

class InsurancePage extends ConsumerWidget {
  const InsurancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(insuranceProfilesProvider);
    final changes = ref.watch(insuranceChangesProvider);
    final history = ref.watch(insuranceBaseHistoryProvider);
    final month = ref.watch(insuranceMonthProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('社保保险'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings/insurance/change'),
            icon: const Icon(Icons.add_task_outlined),
            tooltip: '登记变更',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          _InsuranceHeader(
            onAddProfile: () => context.push('/settings/insurance/profile'),
            onAddChange: () => context.push('/settings/insurance/change'),
          ),
          const SizedBox(height: 18),
          Text('当前参保信息', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          profiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('加载失败：$error'),
            data: (items) => items.isEmpty
                ? const _InsuranceSectionEmpty(message: '还没有参保档案')
                : Column(
                    children: [
                      for (final item in items) ...[
                        _InsuranceProfileCard(item: item),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${insuranceMonthLabel(month)}变更清单',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const Key('insurance-previous-month'),
                onPressed: () =>
                    ref.read(insuranceMonthProvider.notifier).state = DateTime(
                      month.year,
                      month.month - 1,
                    ),
                icon: const Icon(Icons.chevron_left),
                tooltip: '上个月',
              ),
              IconButton(
                key: const Key('insurance-next-month'),
                onPressed: () =>
                    ref.read(insuranceMonthProvider.notifier).state = DateTime(
                      month.year,
                      month.month + 1,
                    ),
                icon: const Icon(Icons.chevron_right),
                tooltip: '下个月',
              ),
            ],
          ),
          changes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('加载失败：$error'),
            data: (items) => items.isEmpty
                ? const _InsuranceSectionEmpty(message: '本月暂无保险变更')
                : Column(
                    children: [
                      for (final item in items) ...[
                        _InsuranceChangeCard(item: item, ref: ref),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Text('缴费基数历史', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('加载失败：$error'),
            data: (items) => items.isEmpty
                ? const _InsuranceSectionEmpty(message: '还没有基数历史')
                : Column(
                    children: [
                      for (final item in items.take(20)) ...[
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.history,
                              color: AppColors.helper,
                            ),
                            title: Text(
                              '${item.employee.name} · ${item.history.effectiveMonth}',
                            ),
                            subtitle: Text(
                              '${InsuranceOptions.typeLabel(item.history.insuranceType ?? 'other')} · 基数 ${item.history.contributionBase?.toStringAsFixed(2) ?? '未填写'} · ${item.history.source ?? '手工维护'}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _InsuranceHeader extends StatelessWidget {
  const _InsuranceHeader({
    required this.onAddProfile,
    required this.onAddChange,
  });

  final VoidCallback onAddProfile;
  final VoidCallback onAddChange;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.techBlue),
                SizedBox(width: 10),
                Text('保险信息独立保存，变更由人工确认办理。'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('insurance-profile-button'),
                    onPressed: onAddProfile,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('维护参保'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('insurance-change-button'),
                    onPressed: onAddChange,
                    icon: const Icon(Icons.add_task_outlined),
                    label: const Text('登记变更'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsuranceProfileCard extends StatelessWidget {
  const _InsuranceProfileCard({required this.item});

  final InsuranceProfileView item;

  @override
  Widget build(BuildContext context) {
    final profile = item.profile;
    return Card(
      child: ListTile(
        leading: Icon(
          profile.isInsured
              ? Icons.verified_user_outlined
              : Icons.person_off_outlined,
          color: profile.isInsured ? AppColors.primary : AppColors.helper,
        ),
        title: Text('${item.employee.name} · ${item.employee.employeeNo}'),
        subtitle: Text(
          profile.isInsured
              ? '${InsuranceOptions.typeLabel(profile.insuranceType ?? 'other')} · 基数 ${profile.contributionBase?.toStringAsFixed(2) ?? '未填写'}${profile.effectiveMonth == null ? '' : ' · ${profile.effectiveMonth}生效'}'
              : '未参保${profile.effectiveMonth == null ? '' : ' · ${profile.effectiveMonth}起生效'}',
        ),
        trailing: IconButton(
          onPressed: () => context.push(
            '/settings/insurance/profile?employeeId=${profile.employeeId}',
          ),
          icon: const Icon(Icons.edit_outlined),
          tooltip: '编辑参保信息',
        ),
      ),
    );
  }
}

class _InsuranceChangeCard extends StatelessWidget {
  const _InsuranceChangeCard({required this.item, required this.ref});

  final InsuranceChangeView item;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final change = item.change;
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.fact_check_outlined,
          color: AppColors.techBlue,
        ),
        title: Text(
          '${item.employee.name} · ${InsuranceOptions.changeTypeLabel(change.changeType)}',
        ),
        subtitle: Text(
          '${change.effectiveMonth} · ${InsuranceOptions.statusLabel(change.processingStatus)}${change.remark == null ? '' : ' · ${change.remark}'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () =>
                  context.push('/settings/insurance/change/${change.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑变更',
            ),
            PopupMenuButton<String>(
              key: Key('insurance-change-actions-${change.id}'),
              onSelected: (status) async {
                try {
                  await ref
                      .read(insuranceRepositoryProvider)
                      .updateChangeStatus(change.id, status);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('更新失败：$error')));
                  }
                }
              },
              itemBuilder: (context) => [
                for (final status in InsuranceOptions.processingStatuses)
                  PopupMenuItem(
                    value: status,
                    child: Text(InsuranceOptions.statusLabel(status)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsuranceSectionEmpty extends StatelessWidget {
  const _InsuranceSectionEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Center(child: Text(message)),
      ),
    );
  }
}
