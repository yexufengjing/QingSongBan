import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHero(),
            const SizedBox(height: 20),
            Text('今日概览', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            ref
                .watch(homeDashboardProvider)
                .when(
                  loading: () => const _DashboardLoading(),
                  error: (error, _) =>
                      _DashboardError(message: error.toString()),
                  data: (stats) => _Dashboard(stats: stats),
                ),
            const SizedBox(height: 20),
            Text('快捷操作', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            _QuickActions(),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();
  @override
  Widget build(BuildContext context) => const Card(
    child: SizedBox(
      height: 164,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.lightDanger,
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: AppColors.danger),
      title: const Text('概览暂时无法加载'),
      subtitle: Text(message),
    ),
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.stats});
  final HomeDashboardStats stats;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.55,
        children: [
          _Metric(
            label: '当前在岗',
            value: stats.activeEmployees,
            color: AppColors.primary,
            route: '/personnel/list',
          ),
          _Metric(
            label: '本月新增',
            value: stats.newEmployees,
            color: AppColors.techBlue,
            route: '/personnel/list',
          ),
          _Metric(
            label: '本月离职',
            value: stats.terminatedEmployees,
            color: const Color(0xFFE98500),
            route: '/attendance/termination',
          ),
          _Metric(
            label: '今日已登记',
            value: stats.todayAttendance,
            color: AppColors.primary,
            route: '/attendance/daily',
          ),
          _Metric(
            label: '异常记录',
            value: stats.anomalies,
            color: AppColors.danger,
            route: '/reports',
          ),
          _Metric(
            label: '待处理提醒',
            value: stats.pendingReminders,
            color: AppColors.purple,
            route: '/settings/reminders',
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    required this.route,
  });
  final String label;
  final int value;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label $value',
    child: InkWell(
      key: Key('home-metric-$label'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    const actions = [
      (
        '新增人员',
        Icons.person_add_alt_1_outlined,
        '/personnel/new',
        AppColors.primary,
      ),
      (
        '今日考勤',
        Icons.fact_check_outlined,
        '/attendance/daily',
        AppColors.techBlue,
      ),
      (
        '请假登记',
        Icons.event_busy_outlined,
        '/attendance/leave/new',
        Color(0xFFE98500),
      ),
      (
        '加班登记',
        Icons.more_time_outlined,
        '/attendance/overtime/new',
        AppColors.purple,
      ),
      (
        '离职登记',
        Icons.person_remove_outlined,
        '/attendance/termination/new',
        AppColors.danger,
      ),
      (
        '保险变更',
        Icons.health_and_safety_outlined,
        '/settings/insurance/change',
        AppColors.techBlue,
      ),
      (
        '工资造资',
        Icons.payments_outlined,
        '/reports/payroll',
        AppColors.primary,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        for (final action in actions)
          Card(
            child: InkWell(
              key: Key('home-action-${action.$1}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(action.$3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.$2, color: action.$4),
                  const SizedBox(width: 8),
                  Text(action.$1),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F7F0), Color(0xFFE8F1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.eco_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('轻松办', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  '人员管理 · 让工作更轻松',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const _StatusBadge(icon: Icons.cloud_off_outlined, label: '本地离线'),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Icon(icon, color: AppColors.body, size: 16),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
