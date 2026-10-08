import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'home_office_illustration.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/design_widgets.dart';
import '../application/home_providers.dart';
import '../../vehicles/application/vehicle_providers.dart';
import '../../vehicles/domain/expense_options.dart';
import '../../attendance/application/daily_attendance_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../purchase/application/purchase_providers.dart';
import '../../reminders/application/reminder_providers.dart';

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
            const HomeReferenceBrand(),
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
              const _HomeSection(
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
                      Icons.directions_car,
                      '/vehicles',
                      AppColors.primary,
                      actionKey: 'home-action-车辆管理',
                    ),
                    _Action(
                      '库存出库',
                      Icons.inventory_2_outlined,
                      '/inventory/issues/new',
                      AppColors.purple,
                    ),
                    _Action(
                      '采购管理',
                      Icons.shopping_cart,
                      '/purchase',
                      Color(0xffff8a00),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _PendingTasks(),
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
              _HomeSection(
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

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    ),
  );
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: BoxConstraints(
      minHeight: 92 + (MediaQuery.textScalerOf(context).scale(18) - 18) * 2,
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        colors: [Color(0xFFD8EDFF), Color(0xFFEEF8FF)],
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        const Positioned(
          right: 0,
          bottom: 0,
          child: ExcludeSemantics(child: HomeOfficeIllustration()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('轻松管理每一天', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                '本地数据 · 有序办理',
                style: TextStyle(color: AppColors.body, fontSize: 12),
              ),
            ],
          ),
        ),
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
    return _HomeSection(
      padding: const EdgeInsets.all(12),
      title: '关键指标',
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
                    DesignIcon(icon, color: color, size: 22),
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

class _PendingTasks extends ConsumerWidget {
  const _PendingTasks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(dailyAttendanceGroupsProvider);
    final attendanceProgress = ref.watch(homeAttendanceProgressProvider);
    final reminders = ref.watch(reminderItemsProvider);
    final warnings = ref.watch(inventoryWarningsProvider);
    final purchases = ref.watch(purchaseDashboardProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 8));
    final date =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final attendanceText = attendanceProgress.when(
      loading: () => '正在读取今日登记进度 · $date',
      error: (_, _) => '今日登记进度加载失败 · $date',
      data: (progress) =>
          '名单 ${progress.rosterCount} 人 · 上午已登记 ${progress.morningRegistered} · 下午已登记 ${progress.afternoonRegistered}',
    );
    final vehicleText = reminders.when(
      loading: () => '正在读取车辆提醒',
      error: (_, _) => '车辆提醒加载失败',
      data: (items) {
        final pending = items
            .where(
              (item) =>
                  item.isPending &&
                  item.reminder.isEnabled &&
                  item.links.any((link) => link.entityType == 'vehicle'),
            )
            .toList();
        final overdue = pending
            .where((item) => item.scheduledAt?.isBefore(today) == true)
            .length;
        // Include all of today and the following seven calendar days.
        final upcoming = pending
            .where(
              (item) =>
                  item.scheduledAt != null &&
                  !item.scheduledAt!.isBefore(today) &&
                  item.scheduledAt!.isBefore(nextWeek),
            )
            .length;
        return pending.isEmpty
            ? '当前没有车辆提醒'
            : '已逾期 $overdue 项 · 7天内 $upcoming 项';
      },
    );
    final inventoryText = warnings.when(
      loading: () => '正在读取库存预警',
      error: (_, _) => '库存预警加载失败',
      data: (items) => items.isEmpty ? '当前没有库存不足物资' : '${items.length} 种物资库存不足',
    );
    final purchaseText = purchases.when(
      loading: () => '正在读取待领取采购',
      error: (_, _) => '待领取采购加载失败',
      data: (value) => value.pendingReceiveCount == 0
          ? '当前没有待领取采购单'
          : '${value.pendingReceiveCount} 单采购待领取',
    );

    return _HomeSection(
      title: '待办事项',
      child: Column(
        children: [
          _PendingTaskRow(
            taskKey: 'home-pending-attendance',
            title: '考勤登记',
            subtitle: attendanceText,
            icon: Icons.calendar_month_outlined,
            color: AppColors.primary,
            action: groups.hasError || attendanceProgress.hasError
                ? '重试'
                : '去登记',
            primary: true,
            onTap: groups.hasError || attendanceProgress.hasError
                ? () {
                    ref.invalidate(dailyAttendanceGroupsProvider);
                    ref.invalidate(homeAttendanceProgressProvider);
                  }
                : () async {
                    await context.push('/attendance/daily');
                    ref.invalidate(homeAttendanceProgressProvider);
                  },
          ),
          const Divider(height: 1),
          _PendingTaskRow(
            taskKey: 'home-pending-reminders',
            title: '车辆提醒',
            subtitle: vehicleText,
            icon: Icons.directions_car_outlined,
            color: AppColors.primary,
            action: reminders.hasError ? '重试' : '查看',
            onTap: reminders.hasError
                ? () => ref.invalidate(reminderItemsProvider)
                : () => context.push('/vehicles/reminders'),
          ),
          const Divider(height: 1),
          _PendingTaskRow(
            taskKey: 'home-pending-inventory',
            title: '库存补充',
            subtitle: inventoryText,
            icon: Icons.inventory_2_outlined,
            color: AppColors.purple,
            action: warnings.hasError ? '重试' : '查看',
            onTap: warnings.hasError
                ? () => ref.invalidate(inventoryWarningsProvider)
                : () => context.push('/inventory/warnings'),
          ),
          const Divider(height: 1),
          _PendingTaskRow(
            taskKey: 'home-pending-purchase',
            title: '采购入库',
            subtitle: purchaseText,
            icon: Icons.shopping_cart_outlined,
            color: AppColors.warning,
            action: purchases.hasError ? '重试' : '去入库',
            outlined: true,
            onTap: purchases.hasError
                ? () => ref.invalidate(purchaseDashboardProvider)
                : () => context.push('/purchase/pending-receive'),
          ),
        ],
      ),
    );
  }
}

class _PendingTaskRow extends StatelessWidget {
  const _PendingTaskRow({
    required this.taskKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.action,
    required this.onTap,
    this.primary = false,
    this.outlined = false,
  });

  final String taskKey, title, subtitle, action;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool primary, outlined;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
      ),
    );
    final button = primary
        ? FilledButton(onPressed: onTap, style: style, child: Text(action))
        : outlined
        ? OutlinedButton(onPressed: onTap, style: style, child: Text(action))
        : FilledButton.tonal(
            onPressed: onTap,
            style: style.copyWith(
              foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
              backgroundColor: const WidgetStatePropertyAll(
                AppColors.lightBlue,
              ),
            ),
            child: Text(action),
          );
    return Padding(
      key: Key(taskKey),
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.body),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          button,
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.body, size: 20),
        ],
      ),
    );
  }
}

class _BusinessActions extends StatelessWidget {
  const _BusinessActions();
  @override
  Widget build(BuildContext context) => const _HomeSection(
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
          '车辆管理',
          Icons.directions_car_outlined,
          '/vehicles/archive',
          AppColors.techBlue,
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
          '采购管理',
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
  Widget build(BuildContext context) => const _HomeSection(
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
          '社保保险',
          Icons.shield_outlined,
          '/settings/insurance',
          AppColors.success,
          actionKey: 'home-action-社保保险',
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
    color: AppColors.lightBlue.withValues(alpha: .45),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      key: actionKey == null ? null : Key(actionKey!),
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.ink),
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
  Widget build(BuildContext context) => const _HomeSection(
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
  Widget build(BuildContext context) => _HomeSection(
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: AppColors.danger),
      title: const Text('概览暂时无法加载'),
      trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
    ),
  );
}
