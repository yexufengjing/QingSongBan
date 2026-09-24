import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/vehicle_providers.dart';
import '../domain/expense_options.dart';
import 'vehicle_metric_grid.dart';

class VehicleExpenseTab extends ConsumerWidget {
  const VehicleExpenseTab({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(vehicleExpenseItemsProvider(vehicle.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Text('费用分析', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            Text(
              '${DateTime.now().year} 年',
              style: Theme.of(context).textTheme.bodyMedium,
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
                _ExpenseOverview(rows: rows, total: total),
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
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ExpenseOverview extends StatelessWidget {
  const _ExpenseOverview({required this.rows, required this.total});

  final List<VehicleExpenseItem> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fuel = rows
        .where((row) => row.category == '油耗费用')
        .fold<int>(0, (sum, row) => sum + row.amountCents);
    final maintenance = rows
        .where((row) => row.category == '维修费用' || row.category == '保养费用')
        .fold<int>(0, (sum, row) => sum + row.amountCents);
    return VehicleMetricGrid(
      items: [
        VehicleMetricData(
          label: '累计总费用',
          value: '¥${(total / 100).toStringAsFixed(0)}',
          color: AppColors.techBlue,
          icon: Icons.account_balance_wallet_outlined,
        ),
        VehicleMetricData(
          label: '油费',
          value: '¥${(fuel / 100).toStringAsFixed(0)}',
          color: Colors.orange,
          icon: Icons.water_drop_outlined,
        ),
        VehicleMetricData(
          label: '维修/保养',
          value: '¥${(maintenance / 100).toStringAsFixed(0)}',
          color: AppColors.purple,
          icon: Icons.build_outlined,
        ),
        VehicleMetricData(
          label: '记录数',
          value: '${rows.length}',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月度费用趋势', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const _ExpenseLegend(),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                                                maximum,
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
                                fontSize: 10,
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('费用构成', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 126,
                  height: 126,
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
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (var index = 0; index < labels.length; index++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: _expenseColors[index],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                labels[index],
                                style: const TextStyle(fontSize: 12),
                              ),
                              const Spacer(),
                              Text(
                                '${total == 0 ? 0 : (amounts[index] * 100 / total).round()}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.body)),
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
