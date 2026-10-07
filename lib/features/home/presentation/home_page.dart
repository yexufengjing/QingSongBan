import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../application/home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeDashboardProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHero(showSaved: dashboard.hasValue),
            const SizedBox(height: 8),
            dashboard.when(
              loading: () => const _DashboardLoading(),
              error: (error, _) => _DashboardError(message: error.toString()),
              data: (stats) => _Dashboard(stats: stats),
            ),
            const SizedBox(height: 8),
            const _QuickActions(),
            const SizedBox(height: 8),
            _PendingReminders(),
            const SizedBox(height: 8),
            const _MoreBusinessTools(),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 150,
    child: Card(child: Center(child: CircularProgressIndicator())),
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
  Widget build(BuildContext context) {
    final currentMonth = AppDateUtils.yearMonth(DateTime.now());
    final metrics = [
      _Metric(
        label: '当前在岗',
        value: stats.activeEmployees,
        color: AppColors.primary,
        route: '/personnel/list?status=active',
      ),
      _Metric(
        label: '本月新增',
        value: stats.newEmployees,
        color: AppColors.techBlue,
        route: '/personnel/list?hireMonth=$currentMonth',
      ),
      _Metric(
        label: '本月离职',
        value: stats.terminatedEmployees,
        color: AppColors.danger,
        route: '/attendance/termination',
      ),
      _Metric(
        label: '今日出勤',
        value: stats.todayAttendance,
        color: AppColors.primary,
        route: '/attendance/daily',
      ),
      _Metric(
        label: '今日请假',
        value: stats.todayLeave,
        color: AppColors.techBlue,
        route: '/attendance/leave',
      ),
      _Metric(
        label: '即将到期',
        value: stats.upcomingReminders,
        color: const Color(0xFFE98500),
        route: '/settings/reminders',
        unit: '项',
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                mainAxisExtent: 58,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, index) => metrics[index],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 30,
                child: TextButton(
                  onPressed: () => context.push('/reports'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('查看汇总'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    required this.route,
    this.unit = '人',
  });
  final String label;
  final int value;
  final Color color;
  final String route;
  final String unit;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label $value $unit',
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('home-metric-$label'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_metricIcon(label), color: color, size: 18),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$value',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          unit,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.body),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.helper,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  IconData _metricIcon(String label) => switch (label) {
    '当前在岗' => Icons.groups_2_outlined,
    '本月新增' => Icons.person_add_alt_1_outlined,
    '本月离职' => Icons.person_remove_outlined,
    '今日出勤' => Icons.fact_check_outlined,
    '今日请假' => Icons.event_busy_outlined,
    '即将到期' => Icons.schedule_outlined,
    _ => Icons.notifications_none_outlined,
  };
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
        '录入新员工信息',
      ),
      (
        '今日考勤',
        Icons.fact_check_outlined,
        '/attendance/daily',
        AppColors.techBlue,
        '记录出勤情况',
      ),
      (
        '请假登记',
        Icons.event_busy_outlined,
        '/attendance/leave/new',
        Color(0xFFE98500),
        '记录请假信息',
      ),
      (
        '加班登记',
        Icons.more_time_outlined,
        '/attendance/overtime/new',
        AppColors.purple,
        '记录加班时长',
      ),
      (
        '离职登记',
        Icons.person_remove_outlined,
        '/attendance/termination/new',
        AppColors.danger,
        '办理离职手续',
      ),
      (
        '保险变更',
        Icons.health_and_safety_outlined,
        '/settings/insurance/change',
        AppColors.primary,
        '社保与商业保险',
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Column(
          children: [
            _SectionHeading(
              title: '快捷操作',
              action: TextButton(
                onPressed: () => context.push('/settings'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('更多功能'),
              ),
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.24,
              children: [
                for (final action in actions)
                  Material(
                    color: action.$4.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      key: Key('home-action-${action.$1}'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => context.push(action.$3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: action.$4,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                action.$2,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              action.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              action.$5,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.showSaved});

  final bool showSaved;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      image: true,
      label: '轻松办人员管理首页，清洁人员与车辆背景，标语：让城市更清洁，让工作更轻松。',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 3.38,
              child: Image.asset(
                'assets/ui/home_header.png',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: _StatusBadge(
                icon: Icons.cloud_off_outlined,
                label: showSaved ? '本地离线 · 已保存' : '本地离线',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreBusinessTools extends StatelessWidget {
  const _MoreBusinessTools();

  @override
  Widget build(BuildContext context) {
    const tools = [
      ('物品领取', Icons.inventory_2_outlined, '/items'),
      ('库存管理', Icons.warehouse_outlined, '/inventory'),
      ('采购管理', Icons.shopping_cart_outlined, '/purchase'),
      ('工资造资', Icons.payments_outlined, '/reports/payroll'),
      ('新建提醒', Icons.add_alert_outlined, '/settings/reminders/new'),
      ('车辆管理', Icons.local_shipping_outlined, '/vehicles'),
      ('园林器械维修', Icons.handyman_outlined, '/garden-tool-repairs'),
      ('年度油耗汇总', Icons.table_chart_outlined, '/vehicles/fuel-summary'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 0,
      children: [
        for (final tool in tools)
          ActionChip(
            key: Key('home-action-${tool.$1}'),
            avatar: Icon(tool.$2, size: 17, color: AppColors.primary),
            label: Text(tool.$1),
            onPressed: () => context.push(tool.$3),
            visualDensity: VisualDensity.compact,
            side: BorderSide.none,
            backgroundColor: Colors.white,
          ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      ?action,
    ],
  );
}

class _PendingReminders extends StatelessWidget {
  const _PendingReminders();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => ref
          .watch(homeDashboardProvider)
          .maybeWhen(
            data: (stats) => Card(
              child: ListTile(
                key: const Key('home-pending-reminders'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.lightGreen,
                  child: Icon(
                    Icons.notifications_none,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('待办提醒'),
                subtitle: Text(
                  stats.pendingReminders == 0
                      ? '当前没有待处理提醒'
                      : '当前有 ${stats.pendingReminders} 项待处理',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.helper,
                ),
                onTap: () => context.push('/settings/reminders'),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.contains('已保存')) ...[
            const Icon(Icons.check_circle, color: AppColors.primary, size: 12),
            const SizedBox(width: 3),
          ],
          Icon(icon, color: AppColors.body, size: 12),
          const SizedBox(width: 3),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
