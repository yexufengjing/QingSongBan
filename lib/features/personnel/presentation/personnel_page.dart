import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../application/personnel_providers.dart';
import 'personnel_widgets.dart';

class PersonnelPage extends ConsumerWidget {
  const PersonnelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(allPersonnelProvider);

    return SafeArea(
      child: employees.when(
        loading: () => const _PersonnelHomeLoading(),
        error: (_, _) => PersonnelErrorState(
          onRetry: () => ref.invalidate(allPersonnelProvider),
        ),
        data: (items) => _PersonnelHomeContent(employees: items),
      ),
    );
  }
}

class _PersonnelHomeContent extends StatelessWidget {
  const _PersonnelHomeContent({required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    final active = employees
        .where((employee) => employee.status == EmployeeStatus.active)
        .length;
    final paused = employees
        .where((employee) => employee.status == EmployeeStatus.paused)
        .length;
    final terminated = employees
        .where((employee) => employee.status == EmployeeStatus.terminated)
        .length;
    final now = DateTime.now();
    final newThisMonth = employees.where((employee) {
      return employee.hireDate.year == now.year &&
          employee.hireDate.month == now.month;
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                icon: const Icon(Icons.chevron_left),
                tooltip: '返回',
              ),
              Expanded(
                child: Text(
                  '人员管理',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${AppDateUtils.yearMonth(now)} · 人员档案',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('档案概览', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    '共 ${employees.length} 条记录',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(14) > 19 ||
                              constraints.maxWidth < 290
                          ? 2
                          : 4;
                      final entries = [
                        (
                          '在岗',
                          active,
                          Icons.groups_outlined,
                          AppColors.techBlue,
                          '/personnel/list?status=${EmployeeStatus.active.name}',
                        ),
                        (
                          '暂停工作',
                          paused,
                          Icons.pause_circle_outline,
                          const Color(0xFFE98500),
                          '/personnel/list?status=${EmployeeStatus.paused.name}',
                        ),
                        (
                          '已离职',
                          terminated,
                          Icons.person_off_outlined,
                          AppColors.danger,
                          '/personnel/list?status=${EmployeeStatus.terminated.name}',
                        ),
                        (
                          '本月新增',
                          newThisMonth,
                          Icons.person_add_alt_1_outlined,
                          AppColors.success,
                          '/personnel/list?hireMonth=${Uri.encodeComponent(AppDateUtils.yearMonth(now))}',
                        ),
                      ];
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final entry in entries)
                            SizedBox(
                              width:
                                  (constraints.maxWidth - (columns - 1) * 6) /
                                  columns,
                              child: _PersonnelStatCard(
                                label: entry.$1,
                                value: '${entry.$2}',
                                icon: entry.$3,
                                foreground: entry.$4,
                                onTap: () => context.push(entry.$5),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.push('/personnel/list'),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('进入人员名单'),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '搜索人员、查看和维护档案',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('档案维护', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _QuickActionCard(
                    icon: Icons.badge_outlined,
                    label: '人员名单',
                    detail: '搜索与筛选',
                    color: AppColors.techBlue,
                    onTap: () => context.push('/personnel/list'),
                  ),
                  const Divider(height: 24),
                  _QuickActionCard(
                    icon: Icons.person_add_alt_1_outlined,
                    label: '新增人员',
                    detail: '建立人员档案',
                    color: AppColors.purple,
                    onTap: () => context.push('/personnel/new'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.lightBlue,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.techBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '资料提示',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.techBlue),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '人员档案、人员状态与考勤参与范围独立维护，人员状态不会替代月度考勤名单。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonnelStatCard extends StatelessWidget {
  const _PersonnelStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.foreground,
    required this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color foreground;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.lightBlue.withValues(alpha: .45),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      key: Key('personnel-stat-$label'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: foreground, size: 22),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  TextSpan(
                    text: '人',
                    style: TextStyle(fontSize: 12, color: foreground),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    ),
    title: Text(label, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(detail),
    trailing: const Icon(Icons.chevron_right, color: AppColors.body),
    onTap: onTap,
  );
}

class _PersonnelHomeLoading extends StatelessWidget {
  const _PersonnelHomeLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
