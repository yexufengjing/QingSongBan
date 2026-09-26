import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../application/vehicle_providers.dart';
import '../domain/fuel_options.dart';

class VehicleFuelTab extends ConsumerStatefulWidget {
  const VehicleFuelTab({
    required this.vehicle,
    this.initialYear,
    this.initialMonth,
    super.key,
  });

  final Vehicle vehicle;
  final int? initialYear;
  final int? initialMonth;

  @override
  ConsumerState<VehicleFuelTab> createState() => _VehicleFuelTabState();
}

class _VehicleFuelTabState extends ConsumerState<VehicleFuelTab> {
  late int _year;
  int? _focusMonth;
  late int _entryMonth;
  final _litersController = TextEditingController();
  final _amountController = TextEditingController();
  final _entryFormKey = GlobalKey<FormState>();
  bool _savingInline = false;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear ?? DateTime.now().year;
    _focusMonth = widget.initialMonth;
    _entryMonth = widget.initialMonth ?? DateTime.now().month;
  }

  @override
  void dispose() {
    _litersController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(vehicleFuelProvider((widget.vehicle.id, _year)));
    final summary = ref.watch(
      vehicleFuelSummaryProvider((widget.vehicle.id, _year)),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '上一年',
              onPressed: () => setState(() => _year--),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('$_year 年', style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              tooltip: '下一年',
              onPressed: () => setState(() => _year++),
              icon: const Icon(Icons.chevron_right),
            ),
            const Spacer(),
            Text('月度录入', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.push('/vehicles/fuel-summary'),
            style: TextButton.styleFrom(foregroundColor: AppColors.techBlue),
            icon: const Icon(Icons.table_chart_outlined, size: 17),
            label: const Text('查看全部车辆年度汇总'),
          ),
        ),
        const SizedBox(height: 4),
        _inlineEntryCard(context),
        const SizedBox(height: 12),
        summary.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('汇总失败：$error'),
          data: (value) => _SummaryCard(summary: value),
        ),
        const SizedBox(height: 12),
        rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('油耗记录加载失败：$error'),
          data: (items) {
            if (items.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.local_gas_station_outlined,
                        size: 42,
                        color: AppColors.helper,
                      ),
                      const SizedBox(height: 8),
                      const Text('尚未录入本年度油耗'),
                      const SizedBox(height: 5),
                      Text(
                        '按月份填写油量和金额，年度汇总会自动更新。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showFuelDialog(context, ref, _focusMonth),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.techBlue,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('录入首个月份'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: items
                  .map(
                    (item) => _FuelCard(
                      item: item,
                      focused: item.month == _focusMonth,
                      onEdit: () =>
                          _showFuelDialog(context, ref, item.month, item),
                      onDelete: () => _delete(context, ref, item),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _inlineEntryCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('车辆月度油耗录入', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      widget.vehicle.vehicleType.name == 'sweeper'
                          ? 'assets/vehicles/sweeper-truck.png'
                          : 'assets/vehicles/water-truck.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                    Text(
                      widget.vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      widget.vehicle.licensePlate ?? widget.vehicle.vehicleNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Form(
                  key: _entryFormKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _entryMonth,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: '月份',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          for (var month = 1; month <= 12; month++)
                            DropdownMenuItem(
                              value: month,
                              child: Text('$month 月'),
                            ),
                        ],
                        onChanged: (month) {
                          if (month != null) {
                            setState(() => _entryMonth = month);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _litersController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '油耗量 (L)',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        validator: (value) => _positiveNumber(value, '油量'),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '金额 (元)',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        validator: (value) => _positiveNumber(value, '金额'),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _savingInline ? null : _saveInline,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.techBlue,
                          ),
                          child: Text(_savingInline ? '保存中…' : '保存录入'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _saveInline() async {
    if (!_entryFormKey.currentState!.validate()) return;
    setState(() => _savingInline = true);
    try {
      final repository = ref.read(fuelRepositoryProvider);
      final existing = await repository.findByMonth(
        widget.vehicle.id,
        _year,
        _entryMonth,
      );
      await repository.save(
        FuelMonthlyDraft(
          vehicleId: widget.vehicle.id,
          year: _year,
          month: _entryMonth,
          liters: double.parse(_litersController.text),
          amountCents: (double.parse(_amountController.text) * 100).round(),
          workDays: existing?.workDays,
          workMileage: existing?.workMileage,
          workHours: existing?.workHours,
          remark: existing?.remark,
        ),
        id: existing?.id,
      );
      ref.invalidate(vehicleFuelProvider((widget.vehicle.id, _year)));
      ref.invalidate(vehicleFuelSummaryProvider((widget.vehicle.id, _year)));
      ref.invalidate(fuelYearSummaryProvider(_year));
      if (mounted) {
        _litersController.clear();
        _amountController.clear();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('油耗已保存')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _savingInline = false);
    }
  }

  Future<void> _showFuelDialog(
    BuildContext context,
    WidgetRef ref,
    int? month, [
    FuelMonthlyRecord? existing,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _FuelEntryDialog(
        month: existing?.month ?? month ?? DateTime.now().month,
        liters: existing?.liters.toString() ?? '',
        amount: existing == null
            ? ''
            : (existing.amountCents / 100).toStringAsFixed(2),
        existing: existing != null,
        onSave: (month, liters, amount) => ref
            .read(fuelRepositoryProvider)
            .save(
              FuelMonthlyDraft(
                vehicleId: widget.vehicle.id,
                year: _year,
                month: month,
                liters: liters,
                amountCents: (amount * 100).round(),
              ),
              id: existing?.id,
            ),
      ),
    );
    if (saved == true) {
      ref.invalidate(vehicleFuelProvider((widget.vehicle.id, _year)));
      ref.invalidate(vehicleFuelSummaryProvider((widget.vehicle.id, _year)));
      ref.invalidate(fuelYearSummaryProvider(_year));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FuelMonthlyRecord item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条油耗记录？'),
        content: const Text('记录会被软删除，年度汇总将不再统计，但可以通过重新录入恢复。'),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => dialogContext.pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(fuelRepositoryProvider)
        .softDelete(widget.vehicle.id, item.id);
    ref.invalidate(vehicleFuelProvider((widget.vehicle.id, _year)));
    ref.invalidate(vehicleFuelSummaryProvider((widget.vehicle.id, _year)));
    ref.invalidate(fuelYearSummaryProvider(_year));
  }
}

class _FuelEntryDialog extends StatefulWidget {
  const _FuelEntryDialog({
    required this.month,
    required this.liters,
    required this.amount,
    required this.existing,
    required this.onSave,
  });
  final int month;
  final String liters;
  final String amount;
  final bool existing;
  final Future<void> Function(int month, double liters, double amount) onSave;
  @override
  State<_FuelEntryDialog> createState() => _FuelEntryDialogState();
}

class _FuelEntryDialogState extends State<_FuelEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _month = TextEditingController(text: '${widget.month}');
  late final _liters = TextEditingController(text: widget.liters);
  late final _amount = TextEditingController(text: widget.amount);
  bool _saving = false;
  @override
  void dispose() {
    _month.dispose();
    _liters.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing ? '编辑月度油耗' : '录入月度油耗'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _month,
            decoration: const InputDecoration(labelText: '月份（1-12）'),
            keyboardType: TextInputType.number,
            validator: (v) => _positiveNumber(v, '月份'),
          ),
          TextFormField(
            controller: _liters,
            decoration: const InputDecoration(labelText: '加油量（升）'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => _positiveNumber(v, '油量'),
          ),
          TextFormField(
            controller: _amount,
            decoration: const InputDecoration(labelText: '油费金额（元）'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => _positiveNumber(v, '油费'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => context.pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? '保存中…' : '保存'),
      ),
    ],
  );
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final month = int.tryParse(_month.text);
    final liters = double.tryParse(_liters.text);
    final amount = double.tryParse(_amount.text);
    if (month == null ||
        month < 1 ||
        month > 12 ||
        liters == null ||
        amount == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(month, liters, amount);
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String? _positiveNumber(String? value, String label) {
  final parsed = double.tryParse(value?.trim() ?? '');
  if (parsed == null || parsed < 0) return '$label格式不正确';
  return null;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final FuelAnnualSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _FuelMetric(
            label: '年度总油耗',
            value: '${summary.totalLiters.toStringAsFixed(0)} L',
            color: AppColors.techBlue,
            icon: Icons.water_drop_outlined,
          ),
          _FuelMetric(
            label: '年度总金额',
            value: '¥${(summary.totalAmountCents / 100).toStringAsFixed(0)}',
            color: Colors.orange,
            icon: Icons.account_balance_wallet_outlined,
          ),
          _FuelMetric(
            label: '月均油耗',
            value: '${summary.averageLiters.toStringAsFixed(0)} L',
            color: AppColors.primary,
            icon: Icons.bar_chart_outlined,
          ),
        ],
      ),
    ),
  );
}

class _FuelMetric extends StatelessWidget {
  const _FuelMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _FuelCard extends StatelessWidget {
  const _FuelCard({
    required this.item,
    required this.focused,
    required this.onEdit,
    required this.onDelete,
  });

  final FuelMonthlyRecord item;
  final bool focused;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    color: focused ? Theme.of(context).colorScheme.primaryContainer : null,
    child: ListTile(
      leading: const Icon(Icons.local_gas_station_outlined),
      title: Text(AppDateUtils.yearMonth(DateTime(item.year, item.month))),
      subtitle: Text(
        '${item.liters.toStringAsFixed(2)} L · ${item.amountCents ~/ 100}.${(item.amountCents % 100).toString().padLeft(2, '0')} 元',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.liters != 0)
            Text(
              '${(item.amountCents / 100 / item.liters).toStringAsFixed(2)} 元/L',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    ),
  );
}
