import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../domain/condition_options.dart';
import '../domain/expense_options.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder_options.dart';
import 'vehicle_metric_grid.dart';

class VehicleExpenseTab extends ConsumerStatefulWidget {
  const VehicleExpenseTab({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  ConsumerState<VehicleExpenseTab> createState() => _VehicleExpenseTabState();
}

class _VehicleExpenseTabState extends ConsumerState<VehicleExpenseTab> {
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final items = ref.watch(
      vehicleExpenseItemsForYearProvider((vehicle.id, _year)),
    );
    final repairs = ref.watch(vehicleRepairOrdersProvider(vehicle.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Text('费用分析', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            DropdownButton<int>(
              value: _year,
              underline: const SizedBox.shrink(),
              items: [
                for (
                  var year = DateTime.now().year - 10;
                  year <= DateTime.now().year + 1;
                  year++
                )
                  DropdownMenuItem(value: year, child: Text('$year 年')),
              ],
              onChanged: (year) {
                if (year != null) setState(() => _year = year);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('费用加载失败：$error'),
          data: (rows) {
            final total = rows.fold<int>(
              0,
              (sum, row) => sum + row.amountCents,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ExpenseOverview(
                  rows: rows,
                  total: total,
                  repairCount: repairs.valueOrNull
                      ?.where((order) => order.reportDate.year == _year)
                      .length,
                ),
                const SizedBox(height: 14),
                if (rows.isNotEmpty) ...[
                  _MonthlyExpenseChart(rows: rows),
                  const SizedBox(height: 14),
                  _ExpenseComposition(rows: rows, total: total),
                  const SizedBox(height: 14),
                ],
                if (rows.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.analytics_outlined,
                            size: 44,
                            color: AppColors.helper,
                          ),
                          const SizedBox(height: 8),
                          const Text('本年度还没有费用流水'),
                          const SizedBox(height: 5),
                          Text(
                            '油耗、维修、保养和其他费用会自动汇总到这里。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Text('费用流水', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...rows.map((row) => _ExpenseCard(item: row)),
                ],
                const SizedBox(height: 14),
                _FrequentRepairProjects(vehicleId: vehicle.id, year: _year),
                const SizedBox(height: 14),
                _VehicleExpenseAlerts(vehicleId: vehicle.id),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ExpenseOverview extends StatelessWidget {
  const _ExpenseOverview({
    required this.rows,
    required this.total,
    required this.repairCount,
  });

  final List<VehicleExpenseItem> rows;
  final int total;
  final int? repairCount;

  @override
  Widget build(BuildContext context) {
    final fuel = rows
        .where((row) => row.category == '油耗费用')
        .fold<int>(0, (sum, row) => sum + row.amountCents);
    final currentMonth = DateTime.now().month;
    final monthTotal = rows
        .where((row) => row.date.month == currentMonth)
        .fold<int>(0, (sum, row) => sum + row.amountCents);
    final fuelShare = total == 0 ? 0 : (fuel * 100 / total).round();
    return VehicleMetricGrid(
      items: [
        VehicleMetricData(
          label: '本年累计总费用',
          value: '¥${(total / 100).toStringAsFixed(0)}',
          color: AppColors.techBlue,
          icon: Icons.account_balance_wallet_outlined,
        ),
        VehicleMetricData(
          label: '本月费用',
          value: '¥${(monthTotal / 100).toStringAsFixed(0)}',
          color: Colors.orange,
          icon: Icons.water_drop_outlined,
        ),
        VehicleMetricData(
          label: '油费占比',
          value: '$fuelShare%',
          color: AppColors.purple,
          icon: Icons.build_outlined,
        ),
        VehicleMetricData(
          label: '维修次数',
          value: repairCount?.toString() ?? '—',
          color: AppColors.primary,
          icon: Icons.receipt_long_outlined,
        ),
      ],
    );
  }
}

const _expenseColors = [
  AppColors.techBlue,
  Color(0xffff8a3d),
  Color(0xff32ba84),
  AppColors.purple,
];

int _expenseCategoryIndex(String category) => switch (category) {
  '油耗费用' => 0,
  '维修费用' => 1,
  '保养费用' => 2,
  _ => 3,
};

class _MonthlyExpenseChart extends StatelessWidget {
  const _MonthlyExpenseChart({required this.rows});

  final List<VehicleExpenseItem> rows;

  @override
  Widget build(BuildContext context) {
    final values = List.generate(12, (_) => List.filled(4, 0));
    for (final row in rows) {
      values[row.date.month - 1][_expenseCategoryIndex(row.category)] +=
          row.amountCents;
    }
    final maximum = values
        .map((month) => month.reduce((a, b) => a + b))
        .reduce(math.max);
    final scaleMax = maximum == 0 ? 100 : maximum;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('月度费用趋势', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                const Text(
                  '单位：元',
                  style: TextStyle(fontSize: 13, color: AppColors.body),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _ExpenseLegend(),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 40,
                    height: 125,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          right: 2,
                          child: _AxisLabel(value: scaleMax),
                        ),
                        Positioned(
                          top: 52,
                          right: 2,
                          child: _AxisLabel(value: scaleMax ~/ 2),
                        ),
                        const Positioned(
                          bottom: 0,
                          right: 2,
                          child: _AxisLabel(value: 0),
                        ),
                      ],
                    ),
                  ),
                  for (var month = 0; month < 12; month++)
                    Expanded(
                      child: Tooltip(
                        message:
                            '${month + 1}月：¥${(values[month].reduce((a, b) => a + b) / 100).toStringAsFixed(0)}',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 125,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: 15,
                                  constraints: BoxConstraints(
                                    minHeight: maximum == 0 ? 0 : 2,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (
                                        var category = 3;
                                        category >= 0;
                                        category--
                                      )
                                        if (values[month][category] > 0)
                                          Container(
                                            height:
                                                120 *
                                                values[month][category] /
                                                scaleMax,
                                            color: _expenseColors[category],
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${month + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseComposition extends StatelessWidget {
  const _ExpenseComposition({required this.rows, required this.total});

  final List<VehicleExpenseItem> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    final amounts = List.filled(4, 0);
    for (final row in rows) {
      amounts[_expenseCategoryIndex(row.category)] += row.amountCents;
    }
    const labels = ['油耗', '维修', '保养', '其他'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('费用构成', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _expenseColors[index].withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        [
                          Icons.local_gas_station,
                          Icons.build,
                          Icons.settings,
                          Icons.more_horiz,
                        ][index],
                        color: _expenseColors[index],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${labels[index]}费用')),
                    Text(
                      '¥${(amounts[index] / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '费用构成图',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              children: [
                SizedBox(
                  width: 156,
                  height: 156,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(126, 126),
                        painter: _DonutPainter(amounts),
                      ),
                      Text(
                        '¥${(total / 100).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 16,
                  children: [
                    for (var index = 0; index < labels.length; index++)
                      Text(
                        '${labels[index]} ${total == 0 ? 0 : (amounts[index] * 100 / total).round()}%',
                        style: TextStyle(color: _expenseColors[index]),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.amounts);

  final List<int> amounts;

  @override
  void paint(Canvas canvas, Size size) {
    final total = amounts.fold<int>(0, (sum, item) => sum + item);
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 50);
    var start = -math.pi / 2;
    for (var index = 0; index < amounts.length; index++) {
      if (total == 0 || amounts[index] == 0) continue;
      final sweep = math.pi * 2 * amounts[index] / total;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = _expenseColors[index]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 17,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      !listEquals(oldDelegate.amounts, amounts);
}

class _ExpenseLegend extends StatelessWidget {
  const _ExpenseLegend();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 10,
    runSpacing: 4,
    children: [
      _LegendItem(label: '油耗', color: AppColors.techBlue),
      _LegendItem(label: '维修', color: Color(0xffff8a3d)),
      _LegendItem(label: '保养', color: Color(0xff32ba84)),
      _LegendItem(label: '其他', color: AppColors.purple),
    ],
  );
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => Text(
    (value / 100).toStringAsFixed(0),
    style: const TextStyle(fontSize: 9, color: AppColors.body),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(radius: 4, backgroundColor: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.body)),
    ],
  );
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.item});

  final VehicleExpenseItem item;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(_iconFor(item.category)),
      title: Text(item.category),
      subtitle: Text(
        '${item.date.year}-${item.date.month.toString().padLeft(2, '0')} · ${item.description}',
      ),
      trailing: Text('${(item.amountCents / 100).toStringAsFixed(2)} 元'),
    ),
  );

  IconData _iconFor(String category) => switch (category) {
    '油耗费用' => Icons.local_gas_station_outlined,
    '维修费用' => Icons.handyman_outlined,
    '保养费用' => Icons.build_circle_outlined,
    _ => Icons.receipt_long_outlined,
  };
}

class _FrequentRepairProjects extends ConsumerWidget {
  const _FrequentRepairProjects({required this.vehicleId, required this.year});

  final int vehicleId;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(vehicleRepairOrdersProvider(vehicleId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('高频维修项目', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            orders.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('维修项目加载失败'),
              data: (items) {
                final frequencies = <String, int>{};
                for (final order in items.where(
                  (item) => item.reportDate.year == year,
                )) {
                  final project = order.project?.trim();
                  final label = project == null || project.isEmpty
                      ? order.symptom.trim()
                      : project;
                  if (label.isNotEmpty) {
                    frequencies.update(
                      label,
                      (count) => count + 1,
                      ifAbsent: () => 1,
                    );
                  }
                }
                final ranked = frequencies.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                if (ranked.isEmpty) {
                  return const Text(
                    '本年度暂无维修项目记录',
                    style: TextStyle(color: AppColors.body),
                  );
                }
                return Column(
                  children: [
                    for (final entry in ranked.take(5))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.handyman_outlined,
                          color: AppColors.techBlue,
                        ),
                        title: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '${entry.value} 次',
                          style: const TextStyle(color: AppColors.body),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleExpenseAlerts extends ConsumerWidget {
  const _VehicleExpenseAlerts({required this.vehicleId});

  final int vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditionState = ref.watch(vehicleConditionItemsProvider(vehicleId));
    final reminderState = ref.watch(reminderItemsProvider);
    final conditions =
        conditionState.valueOrNull ?? const <VehicleConditionItem>[];
    final reminders = reminderState.valueOrNull ?? const <ReminderItem>[];
    final issues = conditions
        .where(
          (item) => switch (item.status) {
            VehicleConditionStatus.normal ||
            VehicleConditionStatus.unavailable => false,
            _ => true,
          },
        )
        .toList();
    final today = DateTime.now();
    final endOfSoon = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 7));
    final dueReminders = reminders.where((item) {
      if (!item.isPending ||
          !item.links.any(
            (link) =>
                link.entityType == 'vehicle' && link.entityId == vehicleId,
          )) {
        return false;
      }
      final date = item.scheduledAt;
      return date != null && !date.isAfter(endOfSoon);
    }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('异常提示', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            if (conditionState.isLoading || reminderState.isLoading)
              const LinearProgressIndicator()
            else if (issues.isEmpty && dueReminders.isEmpty)
              const Text('暂无异常或临近到期提醒', style: TextStyle(color: AppColors.body))
            else ...[
              for (final item in issues)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.warning_amber_outlined,
                    color: AppColors.danger,
                  ),
                  title: Text(
                    VehicleConditionOptions.componentLabel(item.componentType),
                  ),
                  subtitle: Text(
                    item.detail?.trim().isNotEmpty == true
                        ? item.detail!
                        : VehicleConditionOptions.statusLabel(item.status),
                  ),
                ),
              for (final item in dueReminders)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.event_outlined,
                    color: Colors.orange,
                  ),
                  title: Text(item.reminder.title),
                  subtitle: Text(
                    '到期 ${item.scheduledAt!.year}-${item.scheduledAt!.month.toString().padLeft(2, '0')}-${item.scheduledAt!.day.toString().padLeft(2, '0')}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
