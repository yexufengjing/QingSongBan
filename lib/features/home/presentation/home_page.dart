import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'home_office_illustration.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/design_widgets.dart';
import '../application/home_providers.dart';
import '../../vehicles/application/vehicle_providers.dart';
import '../../vehicles/domain/expense_options.dart';

final homeProcessingProvider = StateProvider<bool>((ref) => false);

// Display totals from the existing vehicle expense ledger; no new cost rules.
final _homeExpensesProvider =
    FutureProvider.autoDispose<List<VehicleExpenseItem>>((ref) async {
      final vehicles = await ref.watch(allVehiclesProvider.future);
      final repository = ref.watch(vehicleExpenseRepositoryProvider);
      final rows = await Future.wait([
        for (final vehicle in vehicles) repository.list(vehicle.id),
      ]);
      return rows.expand((row) => row).toList();
    });

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processing = ref.watch(homeProcessingProvider);
    final dashboard = ref.watch(homeDashboardProvider);
    final today = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return SafeArea(
      child: SingleChildScrollView(
        key: PageStorageKey('home-${processing ? 'processing' : 'overview'}'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: '轻松办',
              image: true,
              child: Image.asset(
                'assets/ui/brand_wordmark.png',
                width: 128,
                height: 36,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                excludeFromSemantics: true,
              ),
            ),
            const Text(
              '有序办理 · 高效管理',
              style: TextStyle(color: AppColors.body, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  style: ButtonStyle(
                    shape: const WidgetStatePropertyAll(StadiumBorder()),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : AppColors.lightBlue,
                    ),
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('概览')),
                    ButtonSegment(value: true, label: Text('处理')),
                  ],
                  selected: {processing},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      ref.read(homeProcessingProvider.notifier).state =
                          value.single,
                ),
                Text(
                  '${today.year}年${today.month}月${today.day}日 周${weekdays[today.weekday - 1]}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _WelcomeBanner(),
            const SizedBox(height: 16),
            if (processing) ...[
              const DesignSection(
                title: '常用操作',
                child: DesignGrid(
                  children: [
                    _Action(
                      '每日考勤',
                      Icons.calendar_month_outlined,
                      '/attendance/daily',
                      AppColors.primary,
                      actionKey: 'home-action-今日考勤',
                    ),
                    _Action(
                      '车辆管理',
                      Icons.local_shipping_outlined,
                      '/vehicles',
                      AppColors.success,
                      actionKey: 'home-action-车辆管理',
                    ),
                    _Action(
                      '库存出库',
                      Icons.outbox_outlined,
                      '/inventory/issues/new',
                      AppColors.warning,
                    ),
                    _Action(
                      '采购管理',
                      Icons.shopping_cart_outlined,
                      '/purchase',
                      AppColors.purple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              dashboard.when(
                loading: () => const _Loading(),
                error: (_, _) => _LoadError(
                  onRetry: () => ref.invalidate(homeDashboardProvider),
                ),
                data: (stats) => _PendingTasks(stats: stats),
              ),
              const SizedBox(height: 12),
              const _BusinessActions(),
              const SizedBox(height: 12),
              const _RegistrationActions(),
            ] else ...[
              dashboard.when(
                loading: () => const _Loading(),
                error: (_, _) => _LoadError(
                  onRetry: () => ref.invalidate(homeDashboardProvider),
                ),
                data: (stats) => _Dashboard(stats: stats),
              ),
              const SizedBox(height: 12),
              DesignSection(
                title: '统计口径',
                child: Column(
                  children: [
                    const _ScopeRow(
                      Icons.people_outline,
                      AppColors.success,
                      '人员与考勤',
                      '当前与今日',
                    ),
                    const Divider(height: 16),
                    const _ScopeRow(
                      Icons.build_outlined,
                      AppColors.purple,
                      '维修费用',
                      '本月 / 上月已登记费用',
                    ),
                    const Divider(height: 16),
                    const _ScopeRow(
                      Icons.local_gas_station_outlined,
                      AppColors.warning,
                      '油量与油费',
                      '上月已录合计',
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const DesignIcon(Icons.bar_chart_outlined),
                      title: const Text('查看汇总'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/reports'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        colors: [Color(0xFFD8EDFF), Color(0xFFEEF8FF)],
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '轻松管理每一天',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                '本地数据 · 有序办理',
                style: TextStyle(color: AppColors.body, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const HomeOfficeIllustration(),
      ],
    ),
  );
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.stats});
  final HomeDashboardStats stats;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);
    final expenses = ref.watch(_homeExpensesProvider);
    final fuel = ref.watch(fuelYearSummaryProvider(previous.year));
    String repairTotal(DateTime month) => expenses.when(
      loading: () => '加载中',
      error: (_, _) => '加载失败',
      data: (rows) =>
          (rows
                      .where(
                        (row) =>
                            row.category == '维修费用' &&
                            row.date.year == month.year &&
                            row.date.month == month.month,
                      )
                      .fold<int>(0, (sum, row) => sum + row.amountCents) /
                  100)
              .toStringAsFixed(2),
    );
    final fuelMonth = fuel.valueOrNull?.months
        .where((month) => month.month == previous.month)
        .firstOrNull;
    final fuelState = fuel.isLoading
        ? '加载中'
        : fuel.hasError
        ? '加载失败'
        : fuelMonth == null || fuelMonth.validVehicleCount == 0
        ? '未录入'
        : null;
    var minimumCellWidth = 0.0;
    final values = [
      (repairTotal(now), 16.0),
      (repairTotal(previous), 16.0),
      (fuelState ?? fuelMonth!.totalLiters.toStringAsFixed(2), 16.0),
      (
        fuelState ?? (fuelMonth!.totalAmountCents / 100).toStringAsFixed(2),
        16.0,
      ),
      ('${stats.activeEmployees}', 22.0),
      ('${stats.newEmployees}', 22.0),
      ('${stats.todayAttendance}', 22.0),
      ('${stats.todayLeave}', 22.0),
    ];
    for (final value in values) {
      final painter = TextPainter(
        text: TextSpan(
          text: value.$1,
          style: TextStyle(
            fontSize: value.$2,
            fontWeight: FontWeight.w700,
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width + 4 > minimumCellWidth) {
        minimumCellWidth = painter.width + 4;
      }
      painter.dispose();
    }
    return DesignSection(
      title: '关键指标',
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          DesignGrid(
            minimumCellWidth: minimumCellWidth,
            children: [
              _Metric(
                '当前在岗',
                '${stats.activeEmployees}',
                '人',
                Icons.person_outline,
                AppColors.success,
                '/personnel/list?status=active',
              ),
              _Metric(
                '本月新增',
                '${stats.newEmployees}',
                '人',
                Icons.person_add_alt_1_outlined,
                AppColors.techBlue,
                '/personnel/list?hireMonth=${now.year}-${now.month.toString().padLeft(2, '0')}',
              ),
              _Metric(
                '今日出勤',
                '${stats.todayAttendance}',
                '人',
                Icons.fact_check_outlined,
                AppColors.warning,
                '/attendance/daily',
              ),
              _Metric(
                '今日请假',
                '${stats.todayLeave}',
                '人',
                Icons.event_busy_outlined,
                AppColors.danger,
                '/attendance/leave',
              ),
              _Metric(
                '本月维修费用',
                repairTotal(now),
                '元',
                Icons.build_outlined,
                AppColors.purple,
                '/vehicles/repairs',
                amount: true,
                onRetry: expenses.hasError
                    ? () => ref.invalidate(_homeExpensesProvider)
                    : null,
              ),
              _Metric(
                '上月维修费用',
                repairTotal(previous),
                '元',
                Icons.receipt_long_outlined,
                AppColors.techBlue,
                '/vehicles/repairs',
                amount: true,
                onRetry: expenses.hasError
                    ? () => ref.invalidate(_homeExpensesProvider)
                    : null,
              ),
              _Metric(
                '上月油耗量',
                fuelState ?? fuelMonth!.totalLiters.toStringAsFixed(2),
                'L',
                Icons.local_gas_station_outlined,
                AppColors.success,
                '/vehicles/fuel-summary',
                amount: true,
                onRetry: fuel.hasError
                    ? () =>
                          ref.invalidate(fuelYearSummaryProvider(previous.year))
                    : null,
              ),
              _Metric(
                '上月油耗金额',
                fuelState ??
                    (fuelMonth!.totalAmountCents / 100).toStringAsFixed(2),
                '元',
                Icons.payments_outlined,
                AppColors.warning,
                '/vehicles/fuel-summary',
                amount: true,
                onRetry: fuel.hasError
                    ? () =>
                          ref.invalidate(fuelYearSummaryProvider(previous.year))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          const Text(
            '维修费用：仅含已登记费用。',
            style: TextStyle(color: AppColors.body, fontSize: 12),
          ),
          if (fuelMonth != null)
            Text(
              '上月油耗：已录 ${fuelMonth.validVehicleCount} 辆 · 范围待核实',
              style: const TextStyle(color: AppColors.body, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
    this.label,
    this.value,
    this.unit,
    this.icon,
    this.color,
    this.route, {
    this.amount = false,
    this.onRetry,
  });
  final String label, value, unit, route;
  final IconData icon;
  final Color color;
  final bool amount;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label $value $unit',
    child: Material(
      color: const Color(0xFFF6FAFD),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('home-metric-$label'),
        borderRadius: BorderRadius.circular(8),
        onTap: onRetry ?? () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.textScalerOf(context).scale(12) * 2.8,
                ),
                child: Row(
                  children: [
                    DesignIcon(icon, color: color, size: 26),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.body,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height:
                    MediaQuery.textScalerOf(context).scale(22) * 1.4 +
                    MediaQuery.textScalerOf(context).scale(14) * 1.4,
                child: LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: Text(
                          value,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: amount ? 16 : 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (double.tryParse(value) != null)
                        Text(
                          unit,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '暂无对比',
                style: TextStyle(color: AppColors.body, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PendingTasks extends StatelessWidget {
  const _PendingTasks({required this.stats});
  final HomeDashboardStats stats;
  @override
  Widget build(BuildContext context) => DesignSection(
    title: '待办事项',
    child: Column(
      children: [
        ListTile(
          key: const Key('home-pending-reminders'),
          contentPadding: EdgeInsets.zero,
          leading: const DesignIcon(
            Icons.notifications_none_outlined,
            color: AppColors.warning,
          ),
          title: const Text('待办提醒'),
          subtitle: Text(
            stats.pendingReminders == 0
                ? '当前没有待处理提醒'
                : '${stats.pendingReminders} 项待处理',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/reminders'),
        ),
        const Divider(),
        ListTile(
          key: const Key('home-metric-即将到期'),
          contentPadding: EdgeInsets.zero,
          leading: const DesignIcon(
            Icons.schedule_outlined,
            color: AppColors.purple,
          ),
          title: const Text('即将到期'),
          subtitle: Text('${stats.upcomingReminders} 项 · 未来30天'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/reminders'),
        ),
        const Divider(),
        ListTile(
          key: const Key('home-metric-本月离职'),
          contentPadding: EdgeInsets.zero,
          leading: const DesignIcon(
            Icons.person_remove_outlined,
            color: AppColors.danger,
          ),
          title: const Text('本月离职'),
          subtitle: Text('${stats.terminatedEmployees} 人'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/attendance/termination'),
        ),
      ],
    ),
  );
}

class _BusinessActions extends StatelessWidget {
  const _BusinessActions();
  @override
  Widget build(BuildContext context) => const DesignSection(
    title: '全部业务',
    child: DesignGrid(
      children: [
        _Action('人员管理', Icons.groups_outlined, '/personnel', AppColors.success),
        _Action(
          '考勤管理',
          Icons.calendar_month_outlined,
          '/attendance',
          AppColors.techBlue,
        ),
        _Action(
          '车辆档案',
          Icons.local_shipping_outlined,
          '/vehicles/archive',
          AppColors.warning,
        ),
        _Action(
          '库存管理',
          Icons.warehouse_outlined,
          '/inventory',
          AppColors.purple,
          actionKey: 'home-action-库存管理',
        ),
        _Action(
          '物品领取',
          Icons.inventory_2_outlined,
          '/items',
          AppColors.purple,
          actionKey: 'home-action-物品领取',
        ),
        _Action(
          '采购跟踪',
          Icons.shopping_cart_outlined,
          '/purchase',
          AppColors.techBlue,
          actionKey: 'home-action-采购管理',
        ),
        _Action(
          '器械维修',
          Icons.handyman_outlined,
          '/garden-tool-repairs',
          AppColors.warning,
          actionKey: 'home-action-园林器械维修',
        ),
        _Action(
          '工资管理',
          Icons.payments_outlined,
          '/reports/payroll',
          AppColors.success,
          actionKey: 'home-action-工资造资',
        ),
      ],
    ),
  );
}

class _RegistrationActions extends StatelessWidget {
  const _RegistrationActions();
  @override
  Widget build(BuildContext context) => const DesignSection(
    title: '快捷操作',
    child: DesignGrid(
      children: [
        _Action(
          '新增人员',
          Icons.person_add_alt_1_outlined,
          '/personnel/new',
          AppColors.techBlue,
          actionKey: 'home-action-新增人员',
        ),
        _Action(
          '请假登记',
          Icons.event_busy_outlined,
          '/attendance/leave/new',
          AppColors.warning,
          actionKey: 'home-action-请假登记',
        ),
        _Action(
          '加班登记',
          Icons.more_time_outlined,
          '/attendance/overtime/new',
          AppColors.purple,
          actionKey: 'home-action-加班登记',
        ),
        _Action(
          '离职登记',
          Icons.person_remove_outlined,
          '/attendance/termination/new',
          AppColors.danger,
          actionKey: 'home-action-离职登记',
        ),
        _Action(
          '保险变更',
          Icons.shield_outlined,
          '/settings/insurance/change',
          AppColors.success,
          actionKey: 'home-action-保险变更',
        ),
        _Action(
          '新建提醒',
          Icons.add_alert_outlined,
          '/settings/reminders/new',
          AppColors.warning,
          actionKey: 'home-action-新建提醒',
        ),
        _Action(
          '年度油耗',
          Icons.table_chart_outlined,
          '/vehicles/fuel-summary',
          AppColors.techBlue,
          actionKey: 'home-action-年度油耗汇总',
        ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action(
    this.title,
    this.icon,
    this.route,
    this.color, {
    this.actionKey,
  });
  final String title, route;
  final IconData icon;
  final Color color;
  final String? actionKey;
  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: .045),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      key: actionKey == null ? null : Key(actionKey!),
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Column(
          children: [
            DesignIcon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow(this.icon, this.color, this.title, this.description);
  final IconData icon;
  final Color color;
  final String title, description;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      DesignIcon(icon, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$title：',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              TextSpan(
                text: description,
                style: const TextStyle(color: AppColors.body),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const DesignSection(
    child: SizedBox(
      height: 160,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => DesignSection(
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: AppColors.danger),
      title: const Text('概览暂时无法加载'),
      trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
    ),
  );
}
