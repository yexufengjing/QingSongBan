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
import 'garden_tool_repair_design.dart';

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
    return Theme(
      data: gardenToolRepairTheme(context),
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? '编辑维修记录' : '新增维修记录')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                children: [
                  _buildBasicInfo(unitsAsync),
                  const SizedBox(height: 10),
                  _buildItemsCard(),
                  const SizedBox(height: 10),
                  _buildAttachmentCard(attachmentsAsync),
                ],
              ),
        bottomNavigationBar: _loading ? null : _buildBottomActions(),
      ),
    );
  }

  Widget _buildBasicInfo(
    AsyncValue<List<GardenToolRepairUnit>> unitsAsync,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionIcon(
                icon: Icons.description_outlined,
                color: AppColors.primary,
                background: AppColors.lightGreen,
              ),
              const SizedBox(width: 8),
              Text('基础信息', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 10),
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
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('维修单位'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 10, right: 7),
                              child: Icon(
                                Icons.apartment,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const _CompactFieldDivider(),
                            Expanded(
                              child: unitsAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (error, _) => Text('维修单位加载失败：$error'),
                                data: (units) {
                                  final selectable = units
                                      .where(
                                        (unit) =>
                                            unit.isActive ||
                                            (widget.groupId != null &&
                                                unit.id == _unitId),
                                      )
                                      .toList();
                                  final selectedId =
                                      selectable.any(
                                        (unit) => unit.id == _unitId,
                                      )
                                      ? _unitId
                                      : null;
                                  return DropdownButtonFormField<int>(
                                    key: ValueKey('repair-unit-$selectedId'),
                                    initialValue: selectedId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      filled: false,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                    ),
                                    iconSize: 18,
                                    items: [
                                      for (final unit in selectable)
                                        DropdownMenuItem(
                                          value: unit.id,
                                          child: Text(
                                            unit.isActive
                                                ? unit.name
                                                : '${unit.name}（已停用）',
                                            overflow: TextOverflow.ellipsis,
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
                                    validator: (value) =>
                                        value == null ? '请选择维修单位' : null,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('维修人'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 10, right: 7),
                              child: Icon(
                                Icons.person_outline,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const _CompactFieldDivider(),
                            Expanded(
                              child: TextField(
                                controller: _repairerController,
                                style: const TextStyle(fontSize: 10),
                                decoration: const InputDecoration(
                                  hintText: '选择人员或临时输入姓名',
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                ),
                                onChanged: (_) =>
                                    setState(() => _repairerId = null),
                              ),
                            ),
                            if (_unitId != null)
                              IconButton(
                                tooltip: '新增本单位维修人',
                                visualDensity: VisualDensity.compact,
                                onPressed: _addPerson,
                                icon: const Icon(Icons.person_add_alt_1),
                              ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/garden-tool-repairs/units'),
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('先新增维修单位'),
              ),
            ),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: _remarkController,
            decoration: const InputDecoration(
              labelText: '组备注（可选）',
              isDense: true,
            ),
            maxLines: 1,
          ),
        ],
      ),
    ),
  );

  Widget _buildItemsCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionIcon(
                icon: Icons.format_list_bulleted,
                color: Color(0xFFEF8B27),
                background: Color(0xFFFFF1E8),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _items.add(_RepairItemInput())),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_circle, size: 18),
                  label: const Text('添加明细'),
                ),
                const Spacer(),
                Text(
                  '小计：${formatRepairMoney(_currentSubtotal)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF087F58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _itemRow(int index, _RepairItemInput row) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        _itemField(row.project, width: 62, hint: '项目名称'),
        const SizedBox(width: 2),
        _itemField(row.spec, width: 44, hint: '规格'),
        const SizedBox(width: 2),
        _itemField(row.unit, width: 32, hint: '单位'),
        const SizedBox(width: 2),
        _itemField(
          row.quantity,
          width: 36,
          hint: '数量',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        const SizedBox(width: 2),
        _itemField(
          row.unitPrice,
          width: 44,
          hint: '单价',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
        ),
        const SizedBox(width: 2),
        Container(
          width: 50,
          height: 38,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(formatRepairMoney(_rowAmount(row))),
          ),
        ),
        const SizedBox(width: 2),
        _itemField(row.remark, width: 48, hint: '备注'),
        SizedBox(
          width: 28,
          height: 40,
          child: IconButton(
            tooltip: '删除明细',
            onPressed: () {
              setState(() {
                _items.removeAt(index).dispose();
              });
            },
            color: AppColors.danger,
            padding: EdgeInsets.zero,
            iconSize: 18,
            icon: const Icon(Icons.delete_outline),
          ),
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
    height: 38,
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 10, color: AppColors.helper),
        contentPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _SectionIcon(
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.techBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '票据/照片附件（$total/${GardenToolRepairRepository.maxAttachmentsPerGroup}）',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '支持拍照、相册上传，最多9张',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (attachmentsAsync?.isLoading == true)
              const LinearProgressIndicator()
            else if (attachmentsAsync?.hasError == true)
              Text('已存附件加载失败：${attachmentsAsync!.error}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
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
                if (total < GardenToolRepairRepository.maxAttachmentsPerGroup)
                  _UploadPhotoTile(onTap: () => _choosePhotoSource(9 - total)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() => SafeArea(
    top: false,
    child: Material(
      color: const Color(0xFFEAF8EF),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('当前合计', style: TextStyle(fontSize: 11)),
                  Text(
                    formatRepairMoney(_currentSubtotal),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 34,
              child: VerticalDivider(width: 14, color: AppColors.divider),
            ),
            Expanded(
              flex: 3,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: _saving ? null : () => _save(continueEntry: false),
                child: const Text('保存'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: _saving ? null : () => _save(continueEntry: true),
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
      ),
    ),
  );

  int get _currentSubtotal =>
      _items.fold(0, (sum, item) => sum + _rowAmount(item));

  Future<void> _choosePhotoSource(int available) async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (camera != null && mounted) {
      await _pickPhotos(camera: camera, available: available);
    }
  }

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
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _RepairerNameDialog(),
    );
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
    GardenToolRepairGroup? savedGroup;
    try {
      savedGroup = await ref
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
      _editingGroupId = savedGroup.id;
      for (final pending in List<_PendingRepairPhoto>.from(_pendingPhotos)) {
        await ref
            .read(gardenToolRepairAttachmentServiceProvider)
            .storePhoto(
              groupId: savedGroup.id,
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
      if (mounted) {
        final message = savedGroup == null
            ? '保存维修记录失败：$error'
            : '维修记录已保存，${_pendingPhotos.length} 张附件未保存，可重试：$error';
        _showMessage(message);
      }
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FieldLabel(label),
      const SizedBox(height: 4),
      Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 36,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 7),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                const _CompactFieldDivider(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.body),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppColors.body, fontWeight: FontWeight.w500),
  );
}

class _CompactFieldDivider extends StatelessWidget {
  const _CompactFieldDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 24, color: AppColors.divider);
}

class _ItemHeader extends StatelessWidget {
  const _ItemHeader();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _HeaderCell('项目', 62),
      SizedBox(width: 2),
      _HeaderCell('规格', 44),
      SizedBox(width: 2),
      _HeaderCell('单位', 32),
      SizedBox(width: 2),
      _HeaderCell('数量', 36),
      SizedBox(width: 2),
      _HeaderCell('单价', 44),
      SizedBox(width: 2),
      _HeaderCell('金额', 50),
      SizedBox(width: 2),
      _HeaderCell('备注', 48),
      SizedBox(width: 2),
      _HeaderCell('操作', 28),
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
    height: 30,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
    ),
  );
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({
    required this.icon,
    required this.color,
    this.background,
  });

  final IconData icon;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, size: 18, color: color),
  );
}

class _UploadPhotoTile extends StatelessWidget {
  const _UploadPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: CustomPaint(
      foregroundPainter: _DashedBorderPainter(),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.techBlue),
            SizedBox(height: 5),
            Text('上传照片', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final paint = Paint()
      ..color = AppColors.helper
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 9) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + 5).clamp(0.0, metric.length).toDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
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
          width: 72,
          height: 72,
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
        width: 72,
        height: 72,
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

class _RepairerNameDialog extends StatefulWidget {
  const _RepairerNameDialog();

  @override
  State<_RepairerNameDialog> createState() => _RepairerNameDialogState();
}

class _RepairerNameDialogState extends State<_RepairerNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新增维修人'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: '姓名'),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => Navigator.pop(context, _controller.text.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('添加'),
      ),
    ],
  );
}
