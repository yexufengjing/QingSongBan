import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/garden_tool_repair_providers.dart';
import '../data/garden_tool_repair_repository.dart';
import '../domain/repair_formatters.dart';
import '../domain/repair_models.dart';

class GardenToolRepairFormPage extends ConsumerStatefulWidget {
  const GardenToolRepairFormPage({
    required this.initialMonth,
    this.initialDraft,
    this.groupId,
    super.key,
  });

  final DateTime initialMonth;
  final GardenToolRepairGroupDraft? initialDraft;
  final int? groupId;

  @override
  ConsumerState<GardenToolRepairFormPage> createState() =>
      _GardenToolRepairFormPageState();
}

class _GardenToolRepairFormPageState
    extends ConsumerState<GardenToolRepairFormPage> {
  final _repairerController = TextEditingController();
  final _remarkController = TextEditingController();
  final _picker = ImagePicker();
  final List<_RepairItemInput> _items = [];
  final List<_PendingRepairPhoto> _pendingPhotos = [];
  DateTime _repairMonth = DateTime.now();
  DateTime _repairDate = DateTime.now();
  int? _unitId;
  int? _repairerId;
  int? _editingGroupId;
  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => _editingGroupId != null;

  @override
  void initState() {
    super.initState();
    _repairMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
    );
    final today = DateTime.now();
    _repairDate =
        today.year == _repairMonth.year && today.month == _repairMonth.month
        ? DateTime(today.year, today.month, today.day)
        : _repairMonth;
    if (widget.initialDraft case final draft?) {
      _applyDraft(draft);
    } else {
      _items.add(_RepairItemInput());
    }
    if (widget.groupId case final id?) {
      _editingGroupId = id;
      _loading = true;
      Future<void>.microtask(() => _loadGroup(id));
    }
  }

  @override
  void dispose() {
    _repairerController.dispose();
    _remarkController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(gardenToolRepairUnitsProvider(true));
    final attachmentsAsync = _editingGroupId == null
        ? null
        : ref.watch(gardenToolRepairAttachmentsProvider(_editingGroupId!));
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑维修记录' : '新增维修记录')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              children: [
                _buildBasicInfo(unitsAsync),
                const SizedBox(height: 12),
                _buildItemsCard(),
                const SizedBox(height: 12),
                _buildAttachmentCard(attachmentsAsync),
              ],
            ),
      bottomNavigationBar: _loading ? null : _buildBottomActions(),
    );
  }

  Widget _buildBasicInfo(
    AsyncValue<List<GardenToolRepairUnit>> unitsAsync,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('基础信息', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ChoiceField(
                  label: '维修月份',
                  value: '${_repairMonth.year}年${_repairMonth.month}月',
                  icon: Icons.calendar_month,
                  onTap: _pickMonth,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceField(
                  label: '维修日期',
                  value: '${_repairDate.month}月${_repairDate.day}日',
                  icon: Icons.event,
                  onTap: _pickDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          unitsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('维修单位加载失败：$error'),
            data: (units) {
              final selectable = units
                  .where(
                    (unit) =>
                        unit.isActive ||
                        (widget.groupId != null && unit.id == _unitId),
                  )
                  .toList();
              final selectedId = selectable.any((unit) => unit.id == _unitId)
                  ? _unitId
                  : null;
              return DropdownButtonFormField<int>(
                key: ValueKey('repair-unit-$selectedId'),
                initialValue: selectedId,
                decoration: const InputDecoration(
                  labelText: '维修单位',
                  prefixIcon: Icon(Icons.apartment),
                ),
                items: [
                  for (final unit in selectable)
                    DropdownMenuItem(
                      value: unit.id,
                      child: Text(
                        unit.isActive ? unit.name : '${unit.name}（已停用）',
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == _unitId) return;
                  setState(() {
                    _unitId = value;
                    _repairerId = null;
                    _repairerController.clear();
                  });
                },
                validator: (value) => value == null ? '请选择维修单位' : null,
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _repairerController,
            decoration: InputDecoration(
              labelText: '维修人',
              hintText: '选择人员或临时输入姓名',
              prefixIcon: const Icon(Icons.person_outline),
              suffixIcon: _unitId == null
                  ? null
                  : IconButton(
                      tooltip: '新增本单位维修人',
                      onPressed: _addPerson,
                      icon: const Icon(Icons.person_add_alt_1),
                    ),
            ),
            onChanged: (_) => setState(() => _repairerId = null),
          ),
          if (_unitId != null) ...[
            const SizedBox(height: 6),
            ref
                .watch(gardenToolRepairPersonsProvider(_unitId!))
                .when(
                  loading: () => const SizedBox(height: 2),
                  error: (error, _) => Text('维修人员加载失败：$error'),
                  data: (people) => people.isEmpty
                      ? const SizedBox.shrink()
                      : Wrap(
                          spacing: 6,
                          runSpacing: 0,
                          children: [
                            for (final person in people)
                              ActionChip(
                                label: Text(person.name),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: _repairerId == person.id
                                    ? AppColors.lightGreen
                                    : null,
                                onPressed: () {
                                  setState(() {
                                    _repairerId = person.id;
                                    _repairerController.text = person.name;
                                  });
                                },
                              ),
                          ],
                        ),
                ),
          ],
          if (unitsAsync.valueOrNull?.where((unit) => unit.isActive).isEmpty ??
              true) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/garden-tool-repairs/units'),
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('先新增维修单位'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _remarkController,
            decoration: const InputDecoration(labelText: '组备注（可选）'),
            maxLines: 2,
          ),
        ],
      ),
    ),
  );

  Widget _buildItemsCard() => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '维修明细',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Icon(
                Icons.calculate_outlined,
                color: AppColors.helper,
                size: 18,
              ),
              const SizedBox(width: 5),
              Text('金额自动计算', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                const _ItemHeader(),
                for (var index = 0; index < _items.length; index++)
                  _itemRow(index, _items[index]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _items.add(_RepairItemInput())),
                icon: const Icon(Icons.add),
                label: const Text('添加明细'),
              ),
              const Spacer(),
              Text(
                '小计：${formatRepairMoney(_currentSubtotal)}',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _itemRow(int index, _RepairItemInput row) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        _itemField(row.project, width: 148, hint: '项目名称'),
        const SizedBox(width: 6),
        _itemField(row.spec, width: 96, hint: '规格'),
        const SizedBox(width: 6),
        _itemField(row.unit, width: 72, hint: '单位'),
        const SizedBox(width: 6),
        _itemField(
          row.quantity,
          width: 76,
          hint: '数量',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        const SizedBox(width: 6),
        _itemField(
          row.unitPrice,
          width: 88,
          hint: '单价',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
        ),
        const SizedBox(width: 6),
        Container(
          width: 100,
          height: 48,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(formatRepairMoney(_rowAmount(row))),
        ),
        const SizedBox(width: 6),
        _itemField(row.remark, width: 112, hint: '备注'),
        IconButton(
          tooltip: '删除明细',
          onPressed: () {
            setState(() {
              _items.removeAt(index).dispose();
            });
          },
          color: AppColors.danger,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
  );

  Widget _itemField(
    TextEditingController controller, {
    required double width,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => SizedBox(
    width: width,
    height: 48,
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _buildAttachmentCard(
    AsyncValue<List<GardenToolRepairAttachment>>? attachmentsAsync,
  ) {
    final existing = attachmentsAsync?.valueOrNull ?? const [];
    final total = existing.length + _pendingPhotos.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '票据/照片附件（$total/${GardenToolRepairRepository.maxAttachmentsPerGroup}）',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text('最多9张', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (attachmentsAsync?.isLoading == true)
              const LinearProgressIndicator()
            else if (attachmentsAsync?.hasError == true)
              Text('已存附件加载失败：${attachmentsAsync!.error}'),
            if (existing.isNotEmpty || _pendingPhotos.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final attachment in existing)
                    _ExistingPhotoTile(
                      attachment: attachment,
                      onRemove: () => _removeExistingPhoto(attachment.id),
                    ),
                  for (var index = 0; index < _pendingPhotos.length; index++)
                    _PendingPhotoTile(
                      photo: _pendingPhotos[index],
                      onRemove: () => setState(() {
                        _pendingPhotos.removeAt(index);
                      }),
                    ),
                ],
              ),
            ],
            if (total < GardenToolRepairRepository.maxAttachmentsPerGroup) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _pickPhotos(camera: true, available: 9 - total),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('拍照'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _pickPhotos(camera: false, available: 9 - total),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('相册选择'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() => SafeArea(
    top: false,
    child: Material(
      color: AppColors.card,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('当前合计：'),
                Text(
                  formatRepairMoney(_currentSubtotal),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => _save(continueEntry: false),
                    child: Text(_isEditing ? '保存' : '保存'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () => _save(continueEntry: true),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存并继续'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  int get _currentSubtotal =>
      _items.fold(0, (sum, item) => sum + _rowAmount(item));

  int _rowAmount(_RepairItemInput row) {
    final quantity = double.tryParse(row.quantity.text) ?? 0;
    final price = double.tryParse(row.unitPrice.text) ?? 0;
    if (!quantity.isFinite || !price.isFinite || quantity <= 0 || price < 0) {
      return 0;
    }
    return repairAmountCents(quantity, (price * 100).round());
  }

  Future<void> _loadGroup(int id) async {
    try {
      final entry = await ref
          .read(gardenToolRepairRepositoryProvider)
          .loadGroup(id);
      if (!mounted) return;
      if (entry == null) throw StateError('维修记录组不存在或已删除');
      setState(() {
        _applyDraft(entry.toDraft());
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('维修记录加载失败：$error')));
    }
  }

  void _applyDraft(GardenToolRepairGroupDraft draft) {
    _repairMonth = DateTime.parse('${draft.repairMonth}-01');
    _repairDate = DateTime(
      draft.repairDate.year,
      draft.repairDate.month,
      draft.repairDate.day,
    );
    _unitId = draft.unitId;
    _repairerId = draft.repairerId;
    _repairerController.text = draft.repairerName;
    _remarkController.text = draft.remark;
    for (final item in _items) {
      item.dispose();
    }
    _items
      ..clear()
      ..addAll(draft.items.map(_RepairItemInput.fromDraft));
    if (_items.isEmpty) _items.add(_RepairItemInput());
  }

  Future<void> _pickMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _repairMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择维修月份',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _repairMonth = DateTime(selected.year, selected.month);
      if (_repairDate.year != selected.year ||
          _repairDate.month != selected.month) {
        _repairDate = _repairMonth;
      }
    });
  }

  Future<void> _pickDate() async {
    final firstDate = _repairMonth;
    final lastDate = DateTime(_repairMonth.year, _repairMonth.month + 1, 0);
    final initial =
        _repairDate.year == _repairMonth.year &&
            _repairDate.month == _repairMonth.month
        ? _repairDate
        : firstDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: '选择维修日期',
    );
    if (selected != null && mounted) setState(() => _repairDate = selected);
  }

  Future<void> _addPerson() async {
    final unitId = _unitId;
    if (unitId == null) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增维修人'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '姓名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final person = await ref
          .read(gardenToolRepairRepositoryProvider)
          .addPerson(unitId: unitId, name: name);
      if (!mounted) return;
      setState(() {
        _repairerId = person.id;
        _repairerController.text = person.name;
      });
    } catch (error) {
      if (mounted) _showMessage('新增维修人失败：$error');
    }
  }

  Future<void> _pickPhotos({
    required bool camera,
    required int available,
  }) async {
    final type = await showModalBottomSheet<GardenToolRepairAttachmentType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in GardenToolRepairAttachmentType.values)
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(type.label),
                onTap: () => Navigator.pop(context, type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    try {
      final photos = camera
          ? await _pickCameraPhoto()
          : await _picker.pickMultiImage(limit: available);
      if (!mounted || photos.isEmpty) return;
      setState(() {
        _pendingPhotos.addAll(
          photos
              .take(available)
              .map((photo) => _PendingRepairPhoto(photo, type)),
        );
      });
    } catch (error) {
      if (mounted) _showMessage('选择照片失败：$error');
    }
  }

  Future<void> _removeExistingPhoto(int id) async {
    try {
      await ref
          .read(gardenToolRepairRepositoryProvider)
          .softDeleteAttachment(id);
    } catch (error) {
      if (mounted) _showMessage('移除附件失败：$error');
    }
  }

  Future<List<XFile>> _pickCameraPhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera);
    return photo == null ? const [] : [photo];
  }

  Future<void> _save({required bool continueEntry}) async {
    if (_unitId == null) return _showMessage('请选择维修单位');
    if (_repairerController.text.trim().isEmpty) return _showMessage('请填写维修人');
    if (_items.isEmpty) return _showMessage('至少添加一条维修明细');
    final items = <GardenToolRepairItemDraft>[];
    for (var index = 0; index < _items.length; index++) {
      final row = _items[index];
      final quantity = double.tryParse(row.quantity.text);
      final price = double.tryParse(row.unitPrice.text);
      if (row.project.text.trim().isEmpty) {
        return _showMessage('第${index + 1}条明细的项目名称不能为空');
      }
      if (row.unit.text.trim().isEmpty) {
        return _showMessage('第${index + 1}条明细的计数单位不能为空');
      }
      if (quantity == null || !quantity.isFinite || quantity <= 0) {
        return _showMessage('第${index + 1}条明细的数量必须大于 0');
      }
      if (price == null || !price.isFinite || price < 0) {
        return _showMessage('第${index + 1}条明细的单价必须是大于或等于 0 的金额');
      }
      items.add(
        GardenToolRepairItemDraft(
          projectName: row.project.text,
          specModel: row.spec.text,
          countUnit: row.unit.text,
          quantity: quantity,
          unitPriceCents: (price * 100).round(),
          remark: row.remark.text,
        ),
      );
    }

    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(gardenToolRepairRepositoryProvider)
          .saveGroup(
            GardenToolRepairGroupDraft(
              id: _editingGroupId,
              repairMonth: repairMonthKey(_repairMonth),
              repairDate: _repairDate,
              unitId: _unitId!,
              repairerId: _repairerId,
              repairerName: _repairerController.text,
              remark: _remarkController.text,
              items: items,
            ),
          );
      _editingGroupId = saved.id;
      for (final pending in List<_PendingRepairPhoto>.from(_pendingPhotos)) {
        await ref
            .read(gardenToolRepairAttachmentServiceProvider)
            .storePhoto(
              groupId: saved.id,
              photo: pending.photo,
              attachmentType: pending.type.name,
            );
        _pendingPhotos.remove(pending);
      }
      if (!mounted) return;
      if (continueEntry) {
        setState(() {
          _editingGroupId = null;
          for (final item in _items) {
            item.dispose();
          }
          _items
            ..clear()
            ..add(_RepairItemInput());
          _repairerId = null;
          _repairerController.clear();
          _remarkController.clear();
        });
        _showMessage('已保存，可继续录入下一组');
      } else {
        context.pop();
      }
    } catch (error) {
      if (mounted) _showMessage('保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: Text(value),
    ),
  );
}

class _ItemHeader extends StatelessWidget {
  const _ItemHeader();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _HeaderCell('项目名称', 148),
      SizedBox(width: 6),
      _HeaderCell('规格', 96),
      SizedBox(width: 6),
      _HeaderCell('单位', 72),
      SizedBox(width: 6),
      _HeaderCell('数量', 76),
      SizedBox(width: 6),
      _HeaderCell('单价', 88),
      SizedBox(width: 6),
      _HeaderCell('金额', 100),
      SizedBox(width: 6),
      _HeaderCell('备注', 112),
      SizedBox(width: 48),
    ],
  );
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, this.width);

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 36,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _RepairItemInput {
  _RepairItemInput({
    String project = '',
    String spec = '',
    String unit = '',
    String quantity = '',
    String unitPrice = '',
    String remark = '',
  }) : project = TextEditingController(text: project),
       spec = TextEditingController(text: spec),
       unit = TextEditingController(text: unit),
       quantity = TextEditingController(text: quantity),
       unitPrice = TextEditingController(text: unitPrice),
       remark = TextEditingController(text: remark);

  final TextEditingController project;
  final TextEditingController spec;
  final TextEditingController unit;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController remark;

  factory _RepairItemInput.fromDraft(GardenToolRepairItemDraft draft) =>
      _RepairItemInput(
        project: draft.projectName,
        spec: draft.specModel,
        unit: draft.countUnit,
        quantity: formatRepairQuantity(draft.quantity),
        unitPrice: (draft.unitPriceCents / 100).toStringAsFixed(2),
        remark: draft.remark,
      );

  void dispose() {
    project.dispose();
    spec.dispose();
    unit.dispose();
    quantity.dispose();
    unitPrice.dispose();
    remark.dispose();
  }
}

class _PendingRepairPhoto {
  const _PendingRepairPhoto(this.photo, this.type);

  final XFile photo;
  final GardenToolRepairAttachmentType type;
}

class _ExistingPhotoTile extends ConsumerWidget {
  const _ExistingPhotoTile({required this.attachment, required this.onRemove});

  final GardenToolRepairAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Stack(
    children: [
      FutureBuilder<File>(
        future: ref
            .read(gardenToolRepairAttachmentServiceProvider)
            .resolveFile(attachment),
        builder: (context, snapshot) => Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: snapshot.hasData
              ? Image.file(snapshot.data!, fit: BoxFit.cover)
              : const Icon(Icons.image_outlined, color: AppColors.helper),
        ),
      ),
      Positioned(
        top: 1,
        right: 1,
        child: IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 16),
        ),
      ),
    ],
  );
}

class _PendingPhotoTile extends StatelessWidget {
  const _PendingPhotoTile({required this.photo, required this.onRemove});

  final _PendingRepairPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        width: 84,
        height: 84,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Image.file(File(photo.photo.path), fit: BoxFit.cover),
      ),
      Positioned(
        left: 2,
        bottom: 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text(
              photo.type.label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ),
      Positioned(
        top: 1,
        right: 1,
        child: IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 16),
        ),
      ),
    ],
  );
}
