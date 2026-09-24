import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../application/vehicle_providers.dart';
import '../domain/vehicle_options.dart';

class VehicleFormPage extends ConsumerStatefulWidget {
  const VehicleFormPage({this.vehicleId, super.key});

  final int? vehicleId;

  @override
  ConsumerState<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends ConsumerState<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _departmentController = TextEditingController();
  final _areaController = TextEditingController();
  final _personController = TextEditingController();
  final _remarkController = TextEditingController();
  VehicleType _type = VehicleType.sweeper;
  VehicleStatus _status = VehicleStatus.normal;
  DateTime? _purchaseDate;
  bool _initialized = false;
  bool _saving = false;

  bool get editing => widget.vehicleId != null;

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _numberController,
      _plateController,
      _brandController,
      _modelController,
      _departmentController,
      _areaController,
      _personController,
      _remarkController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(Vehicle vehicle) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = vehicle.name;
    _numberController.text = vehicle.vehicleNo;
    _plateController.text = vehicle.licensePlate ?? '';
    _brandController.text = vehicle.brand ?? '';
    _modelController.text = vehicle.model ?? '';
    _departmentController.text = vehicle.department ?? '';
    _areaController.text = vehicle.workArea ?? '';
    _personController.text = vehicle.responsiblePerson ?? '';
    _remarkController.text = vehicle.remark ?? '';
    _type = vehicle.vehicleType;
    _status = vehicle.status;
    _purchaseDate = vehicle.purchaseDate;
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicleId == null
        ? null
        : ref.watch(vehicleProvider(widget.vehicleId!));
    return Scaffold(
      appBar: AppBar(title: Text(editing ? '编辑车辆' : '新增车辆')),
      body: vehicle == null
          ? _formBody(context)
          : vehicle.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (item) {
                if (item == null || item.isDeleted) {
                  return const Center(child: Text('车辆不存在或已删除'));
                }
                _fill(item);
                return _formBody(context);
              },
            ),
    );
  }

  Widget _formBody(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _section('基础信息', Icons.local_shipping_outlined, [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '车辆名称 *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入车辆名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numberController,
              decoration: const InputDecoration(
                labelText: '车辆编号 *',
                hintText: '例如：SW-001',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入车辆编号' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateController,
              decoration: const InputDecoration(labelText: '车牌号'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<VehicleType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '车辆类型'),
              items: [
                for (final type in VehicleType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(VehicleOptions.typeLabel(type)),
                  ),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
          ]),
          const SizedBox(height: 14),
          _section('使用信息', Icons.badge_outlined, [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: '品牌'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(labelText: '型号'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(labelText: '使用部门'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _areaController,
                    decoration: const InputDecoration(labelText: '工作区域'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _personController,
              decoration: const InputDecoration(labelText: '责任人'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('购置日期'),
              subtitle: Text(AppDateUtils.formatDate(_purchaseDate)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                    initialDate: _purchaseDate ?? DateTime.now(),
                  );
                  if (picked != null) setState(() => _purchaseDate = picked);
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          _section('当前状态', Icons.info_outline, [
            DropdownButtonFormField<VehicleStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: '车辆状态'),
              items: [
                for (final status in VehicleStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(VehicleOptions.statusLabel(status)),
                  ),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 8),
            Text(
              VehicleOptions.statusDescription(_status),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _remarkController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '备注'),
            ),
          ]),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中...' : '保存车辆'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(vehicleRepositoryProvider)
          .save(
            id: widget.vehicleId,
            draft: VehicleDraft(
              name: _nameController.text,
              vehicleNo: _numberController.text,
              licensePlate: _plateController.text,
              vehicleType: _type,
              brand: _brandController.text,
              model: _modelController.text,
              purchaseDate: _purchaseDate,
              department: _departmentController.text,
              workArea: _areaController.text,
              responsiblePerson: _personController.text,
              status: _status,
              remark: _remarkController.text,
            ),
          );
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
