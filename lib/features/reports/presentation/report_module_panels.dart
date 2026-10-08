import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../payroll/application/payroll_providers.dart';
import '../../payroll/domain/payroll_options.dart';
import '../../vehicles/application/vehicle_providers.dart';
import '../../vehicles/domain/expense_options.dart';

// Read-only projections of existing ledgers; no new records or calculation rules.
final _reportExpenses = FutureProvider.autoDispose<List<VehicleExpenseItem>>((
  ref,
) async {
  final vehicles = await ref.watch(allVehiclesProvider.future);
  final repository = ref.watch(vehicleExpenseRepositoryProvider);
  final rows = await Future.wait(
    vehicles.map((vehicle) => repository.list(vehicle.id)),
  );
  return rows.expand((items) => items).toList();
});

bool _inMonth(DateTime date, DateTime month) =>
    date.year == month.year && date.month == month.month;
String _number(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
String _money(num value) => '${value.toStringAsFixed(2)}元';

class ReportGrid extends StatelessWidget {
  const ReportGrid({required this.children, this.columns = 4, super.key});
  final List<ReportMetric> children;
  final int columns;
  @override
  Widget build(BuildContext context) {
    var minimumCellWidth = 0.0;
    for (final item in children) {
      final number =
          RegExp(r'^([+-]?\d+(?:\.\d+)?)(.*)$')
              .firstMatch(item.value)
              ?.group(1) ??
          item.value;
      final painter = TextPainter(
        text: TextSpan(
          text: number,
          style: TextStyle(
            fontSize: item.value.endsWith('元') ? 16 : 22,
            fontWeight: FontWeight.w600,
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          ),
        ),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width + 8 > minimumCellWidth) {
        minimumCellWidth = painter.width + 8;
      }
      painter.dispose();
    }
    return DesignGrid(
      columns: columns,
      minimumCellWidth: minimumCellWidth,
      children: children,
    );
  }
}

class ReportMetric extends StatelessWidget {
  const ReportMetric(
    this.label,
    this.value,
    this.icon, {
    this.color = AppColors.primary,
    super.key,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final parts = RegExp(r'^([+-]?\d+(?:\.\d+)?)(.*)$').firstMatch(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesignIcon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 3,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                parts?.group(1) ?? value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: value.endsWith('元') ? 16 : 22,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (parts != null && parts.group(2)!.isNotEmpty)
                Text(
                  parts.group(2)!,
                  style: const TextStyle(fontSize: 14, color: AppColors.body),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class VehicleReportPanel extends ConsumerWidget {
  const VehicleReportPanel({required this.month, super.key});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuel = ref.watch(fuelYearSummaryProvider(month.year));
    final expenses = ref.watch(_reportExpenses);
    return expenses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          _ReportError(error, () => ref.invalidate(_reportExpenses)),
      data: (items) => fuel.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ReportError(
          error,
          () => ref.invalidate(fuelYearSummaryProvider(month.year)),
        ),
        data: (year) {
          final repairs = items
              .where(
                (item) => item.category == '维修费用' && _inMonth(item.date, month),
              )
              .toList();
          final monthlyFuel = year.months.firstWhere(
            (item) => item.month == month.month,
          );
          final vehicles = year.vehicles;
          final recorded = monthlyFuel.validVehicleCount;
          final amount = repairs.fold<int>(
            0,
            (sum, item) => sum + item.amountCents,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              DesignSection(
                title: '车辆汇总',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReportGrid(
                      children: [
                        ReportMetric(
                          '维修费用',
                          _money(amount / 100),
                          Icons.build_outlined,
                          color: AppColors.warning,
                        ),
                        ReportMetric(
                          '加油量',
                          recorded == 0
                              ? '未录入'
                              : '${_number(monthlyFuel.totalLiters)}L',
                          Icons.local_gas_station_outlined,
                          color: AppColors.success,
                        ),
                        ReportMetric(
                          '加油金额',
                          recorded == 0
                              ? '未录入'
                              : _money(monthlyFuel.totalAmountCents / 100),
                          Icons.payments_outlined,
                        ),
                        ReportMetric(
                          '已录油耗车辆',
                          '$recorded辆',
                          Icons.directions_car_outlined,
                          color: AppColors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '维修按费用台账日期统计；油耗按录入月份统计。',
                      style: TextStyle(fontSize: 12, color: AppColors.body),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DesignSection(
                title: '车辆明细',
                trailing: TextButton(
                  onPressed: () => context.push('/vehicles/fuel-summary'),
                  child: const Text('全年油耗'),
                ),
                child: Column(
                  children: [
                    if (vehicles.isEmpty) const Text('暂无车辆记录'),
                    for (final item in vehicles) ...[
                      _RecordSection(
                        title:
                            '${item.vehicle.vehicleNo} · ${item.vehicle.name}',
                        subtitle: item.recordsByMonth[month.month] == null
                            ? '本月油耗未录入'
                            : '本月油耗已录入',
                        onTap: () =>
                            context.push('/vehicles/${item.vehicle.id}'),
                        children: [
                          ReportMetric(
                            '维修',
                            _money(
                              repairs
                                      .where(
                                        (row) =>
                                            row.vehicleId == item.vehicle.id,
                                      )
                                      .fold<int>(
                                        0,
                                        (sum, row) => sum + row.amountCents,
                                      ) /
                                  100,
                            ),
                            Icons.build_outlined,
                            color: AppColors.warning,
                          ),
                          ReportMetric(
                            '加油量',
                            item.recordsByMonth[month.month] == null
                                ? '未录入'
                                : '${_number(item.recordsByMonth[month.month]!.liters)}L',
                            Icons.local_gas_station_outlined,
                            color: AppColors.success,
                          ),
                          ReportMetric(
                            '加油金额',
                            item.recordsByMonth[month.month] == null
                                ? '未录入'
                                : _money(
                                    item
                                            .recordsByMonth[month.month]!
                                            .amountCents /
                                        100,
                                  ),
                            Icons.payments_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class InventoryReportPanel extends ConsumerWidget {
  const InventoryReportPanel({required this.month, super.key});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(inventoryTransactionsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ReportError(
          error,
          () => ref.invalidate(inventoryTransactionsProvider),
        ),
        data: (all) {
          final rows =
              all.where((row) => _inMonth(row.occurredAt, month)).toList()
                ..sort((a, b) {
                  final date = a.occurredAt.compareTo(b.occurredAt);
                  return date == 0 ? a.id.compareTo(b.id) : date;
                });
          final groups = <int, List<InventoryTransaction>>{};
          for (final row in rows) {
            groups.putIfAbsent(row.materialId, () => []).add(row);
          }
          bool continuous(List<InventoryTransaction> items) {
            for (var i = 1; i < items.length; i++) {
              if ((items[i].stockBefore - items[i - 1].stockAfter).abs() >
                  .000001) {
                return false;
              }
            }
            return true;
          }

          final verified = groups.values.where(continuous).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              DesignSection(
                title: '库存汇总',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReportGrid(
                      children: [
                        ReportMetric(
                          '入库物资',
                          '${rows.where((row) => row.transactionType == 'receipt').map((row) => row.materialId).toSet().length}种',
                          Icons.move_to_inbox_outlined,
                        ),
                        ReportMetric(
                          '领用物资',
                          '${rows.where((row) => row.transactionType == 'issue').map((row) => row.materialId).toSet().length}种',
                          Icons.outbox_outlined,
                          color: AppColors.success,
                        ),
                        ReportMetric(
                          '有连续流水',
                          '$verified种',
                          Icons.inventory_2_outlined,
                          color: AppColors.purple,
                        ),
                        ReportMetric(
                          '流水待核实',
                          '${groups.length - verified}种',
                          Icons.fact_check_outlined,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '不同单位不汇总数量。期初、期末显示本月首末笔流水余额；无流水物资未纳入，历史余额待核实。',
                      style: TextStyle(fontSize: 12, color: AppColors.body),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DesignSection(
                title: '物资明细',
                trailing: TextButton(
                  onPressed: () => context.push('/inventory/transactions'),
                  child: const Text('查看流水'),
                ),
                child: Column(
                  children: [
                    if (groups.isEmpty) const Text('本月暂无库存流水'),
                    for (final items in groups.values) ...[
                      _RecordSection(
                        title: items.last.materialNameSnapshot,
                        subtitle: continuous(items)
                            ? '流水连续 · ${items.length}笔'
                            : '历史流水待核实',
                        onTap: () => context.push(
                          '/inventory/materials/${items.last.materialId}',
                        ),
                        children: [
                          ReportMetric(
                            '期初流水余额',
                            '${_number(items.first.stockBefore)}${items.first.unitSnapshot}',
                            Icons.inventory_outlined,
                          ),
                          ReportMetric(
                            '入库',
                            '${_number(items.where((row) => row.transactionType == 'receipt').fold<double>(0, (sum, row) => sum + row.quantityChange))}${items.last.unitSnapshot}',
                            Icons.move_to_inbox_outlined,
                          ),
                          ReportMetric(
                            '领用',
                            '${_number(-items.where((row) => row.transactionType == 'issue').fold<double>(0, (sum, row) => sum + row.quantityChange))}${items.last.unitSnapshot}',
                            Icons.outbox_outlined,
                            color: AppColors.success,
                          ),
                          ReportMetric(
                            '期末流水余额',
                            continuous(items)
                                ? '${_number(items.last.stockAfter)}${items.last.unitSnapshot}'
                                : '待核实',
                            Icons.inventory_2_outlined,
                            color: AppColors.purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class PayrollReportPanel extends ConsumerStatefulWidget {
  const PayrollReportPanel({required this.month, super.key});
  final DateTime month;
  @override
  ConsumerState<PayrollReportPanel> createState() => _PayrollReportPanelState();
}

class _PayrollReportPanelState extends ConsumerState<PayrollReportPanel> {
  int? _batchId;

  @override
  Widget build(BuildContext context) => ref
      .watch(payrollBatchesProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _ReportError(error, () => ref.invalidate(payrollBatchesProvider)),
        data: (all) {
          final batches = all
              .where(
                (batch) =>
                    batch.payrollMonth == payrollYearMonth(widget.month) &&
                    !batch.isDeleted,
              )
              .toList();
          if (batches.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DesignSection(
                  title: '工资汇总',
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('本月暂无工资批次'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/reports/payroll'),
                        child: const Text('查看工资管理'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          final batch =
              batches.where((batch) => batch.id == _batchId).firstOrNull ??
              batches.first;
          final validation = ref.watch(payrollValidationProvider(batch.id));
          final items = ref.watch(payrollItemsProvider(batch.id));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              DesignSection(
                title: '工资汇总',
                trailing: TextButton(
                  onPressed: () =>
                      context.push('/reports/payroll/edit/${batch.id}'),
                  child: const Text('查看批次'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (batches.length > 1)
                      DropdownButtonFormField<int>(
                        initialValue: batch.id,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '工资批次'),
                        items: [
                          for (final item in batches)
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                        ],
                        onChanged: (id) => setState(() => _batchId = id),
                      )
                    else
                      Text(
                        batch.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '批次状态：${PayrollOptions.statusLabel(batch.status)}',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    ReportGrid(
                      children: [
                        ReportMetric(
                          '应发工资',
                          _money(batch.baseWageTotal + batch.subsidyTotal),
                          Icons.account_balance_wallet_outlined,
                        ),
                        ReportMetric(
                          '保险扣款',
                          _money(batch.insuranceDeductionTotal),
                          Icons.shield_outlined,
                          color: AppColors.warning,
                        ),
                        ReportMetric(
                          '实发工资',
                          _money(batch.finalWageTotal),
                          Icons.payments_outlined,
                          color: AppColors.success,
                        ),
                        ReportMetric(
                          '工资人数',
                          '${batch.employeeCount}人',
                          Icons.people_outline,
                          color: AppColors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '金额来自当前工资批次保存结果。',
                      style: TextStyle(fontSize: 12, color: AppColors.body),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DesignSection(
                title: '工资检查',
                child: validation.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('检查结果暂时不可用'),
                  data: (value) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (value.errors.isEmpty && value.warnings.isEmpty)
                        const Text('当前没有待检查项'),
                      for (final issue in [...value.errors, ...value.warnings])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            issue.message,
                            style: const TextStyle(color: AppColors.warning),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DesignSection(
                title: '工资明细',
                child: items.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => const Text('明细暂时不可用'),
                  data: (rows) => Column(
                    children: [
                      for (final row in rows) ...[
                        _RecordSection(
                          title: row.employee?.name ?? '人员已删除',
                          subtitle: '工号：${row.employee?.employeeNo ?? '—'}',
                          onTap: () => context.push(
                            '/reports/payroll/item/${row.item.id}',
                          ),
                          children: [
                            ReportMetric(
                              '应发',
                              _money(row.item.baseWage + row.item.subsidy),
                              Icons.account_balance_wallet_outlined,
                            ),
                            ReportMetric(
                              '扣款',
                              _money(row.item.insuranceDeduction),
                              Icons.shield_outlined,
                              color: AppColors.warning,
                            ),
                            ReportMetric(
                              '实发',
                              _money(row.item.finalWage),
                              Icons.payments_outlined,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _RecordSection extends StatelessWidget {
  const _RecordSection({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final List<ReportMetric> children;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.divider),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Row(
            children: [
              const DesignIcon(Icons.description_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.body),
            ],
          ),
        ),
        const Divider(height: 24),
        ReportGrid(columns: children.length, children: children),
      ],
    ),
  );
}

class _ReportError extends StatelessWidget {
  const _ReportError(this.error, this.onRetry);
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('汇总暂时不可用：$error'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}
