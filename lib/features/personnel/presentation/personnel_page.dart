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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '人员管理',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '档案清晰，现场协作更轻松',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => context.push('/personnel/list'),
                icon: const Icon(Icons.list_alt_outlined),
                tooltip: '人员名单',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _PersonnelHero(),
          const SizedBox(height: 22),
          PersonnelSectionTitle(
            title: '档案概览',
            action: Text(
              '${employees.length} 条记录',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _PersonnelStatCard(
                label: '在岗',
                value: '$active',
                icon: Icons.verified_user_outlined,
                background: AppColors.lightGreen,
                foreground: AppColors.primary,
                onTap: () => context.push(
                  '/personnel/list?status=${EmployeeStatus.active.name}',
                ),
              ),
              _PersonnelStatCard(
                label: '暂停工作',
                value: '$paused',
                icon: Icons.pause_circle_outline,
                background: AppColors.lightBlue,
                foreground: AppColors.techBlue,
                onTap: () => context.push(
                  '/personnel/list?status=${EmployeeStatus.paused.name}',
                ),
              ),
              _PersonnelStatCard(
                label: '已离职',
                value: '$terminated',
                icon: Icons.person_off_outlined,
                background: AppColors.lightDanger,
                foreground: AppColors.danger,
                onTap: () => context.push(
                  '/personnel/list?status=${EmployeeStatus.terminated.name}',
                ),
              ),
              _PersonnelStatCard(
                label: '本月新增',
                value: '$newThisMonth',
                icon: Icons.person_add_alt_1_outlined,
                background: AppColors.lightOrange,
                foreground: const Color(0xFFE98500),
                onTap: () => context.push(
                  '/personnel/list?hireMonth=${Uri.encodeComponent(AppDateUtils.yearMonth(now))}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PersonnelSectionTitle(
            title: '快速操作',
            action: TextButton(
              onPressed: () => context.push('/personnel/list'),
              child: const Text('查看全部'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.person_add_alt_1_outlined,
                  label: '新增人员',
                  detail: '建立人员档案',
                  color: AppColors.primary,
                  onTap: () => context.push('/personnel/new'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.badge_outlined,
                  label: '人员名单',
                  detail: '搜索与筛选',
                  color: AppColors.techBlue,
                  onTap: () => context.push('/personnel/list'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Card(
            color: AppColors.lightBlue,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.layers_outlined, color: AppColors.techBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '人员档案、人员状态与考勤参与范围独立维护，人员状态不会替代月度考勤名单。',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.ink),
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

class _PersonnelHero extends StatelessWidget {
  const _PersonnelHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F7F0), Color(0xFFE8F1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.groups_2_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地档案库', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  '所有修改自动保存到本地设备',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.cloud_off_outlined, color: AppColors.body),
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
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: Key('personnel-stat-$label'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: foreground, size: 18),
                  ),
                ],
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 14),
              Text(label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonnelHomeLoading extends StatelessWidget {
  const _PersonnelHomeLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
