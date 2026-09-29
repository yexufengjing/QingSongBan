import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_widgets.dart';

class InventoryMaterialFormPage extends ConsumerStatefulWidget {
  const InventoryMaterialFormPage({super.key, this.materialId});
  final int? materialId;

  @override
  ConsumerState<InventoryMaterialFormPage> createState() =>
      _InventoryMaterialFormPageState();
}

class _InventoryMaterialFormPageState
    extends ConsumerState<InventoryMaterialFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _model = TextEditingController();
  final _unit = TextEditingController(text: '件');
  final _location = TextEditingController();
  final _minStock = TextEditingController(text: '0');
  final _maxStock = TextEditingController();
  final _source = TextEditingController();
  final _remark = TextEditingController();
  late final Future<InventoryMaterial?>? _material;
  bool _initialized = false;
  bool _warningEnabled = true;
  bool _common = false;
  int? _categoryId;
  String _status = 'active';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _material = widget.materialId == null
        ? null
        : ref.read(inventoryServiceProvider).getMaterial(widget.materialId!);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _model.dispose();
    _unit.dispose();
    _location.dispose();
    _minStock.dispose();
    _maxStock.dispose();
    _source.dispose();
    _remark.dispose();
    super.dispose();
  }

  void _fill(InventoryMaterial material) {
    if (_initialized) return;
    _initialized = true;
    _code.text = material.materialCode;
    _name.text = material.materialName;
    _model.text = material.modelSpec ?? '';
    _unit.text = material.unitName;
    _location.text = material.storageLocation ?? '';
    _minStock.text = '${material.minStock}';
    _maxStock.text = material.maxStock?.toString() ?? '';
    _source.text = material.defaultSource ?? '';
    _remark.text = material.remark ?? '';
    _warningEnabled = material.warningEnabled;
    _common = material.isCommon;
    _categoryId = material.categoryId;
    _status = material.status;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final minStock = double.parse(_minStock.text.trim());
    final maxStock = _maxStock.text.trim().isEmpty
        ? null
        : double.tryParse(_maxStock.text.trim());
    final draft = InventoryMaterialDraft(
      materialCode: _code.text.trim(),
      materialName: _name.text.trim(),
      categoryId: _categoryId,
      modelSpec: _optional(_model.text),
      unitName: _unit.text.trim(),
      storageLocation: _optional(_location.text),
      minStock: minStock,
      maxStock: maxStock,
      defaultSource: _optional(_source.text),
      warningEnabled: _warningEnabled,
      isCommon: _common,
      status: _status,
      remark: _optional(_remark.text),
    );
    setState(() => _saving = true);
    try {
      final service = ref.read(inventoryServiceProvider);
      if (widget.materialId == null) {
        await service.createMaterial(draft);
      } else {
        await service.updateMaterial(widget.materialId!, draft);
      }
      ref.invalidate(inventoryMaterialsProvider);
      ref.invalidate(inventoryStockProvider);
      ref.invalidate(inventoryWarningsProvider);
      ref.invalidate(inventoryOverviewProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.materialId == null ? '物资已新增' : '物资信息已保存'),
          ),
        );
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新增物资分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分类名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('新增'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final id = await ref.read(inventoryServiceProvider).createCategory(name);
      ref.invalidate(inventoryCategoriesProvider);
      await ref.read(inventoryCategoriesProvider.future);
      if (mounted) setState(() => _categoryId = id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('新增分类失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(inventoryCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.materialId == null ? '新增物资' : '编辑物资')),
      body: categories.when(
        loading: () => const InventoryLoadingState(),
        error: (_, _) => InventoryErrorState(
          onRetry: () => ref.invalidate(inventoryCategoriesProvider),
        ),
        data: (groups) => _materialContent(groups),
      ),
    );
  }

  Widget _materialContent(List<InventoryCategory> groups) {
    Widget formContent(InventoryMaterial? material) {
      if (material != null) _fill(material);
      if (widget.materialId != null && material == null) {
        return const InventoryEmptyState(
          title: '物资不存在',
          message: '该物资档案可能已被移除。',
        );
      }
      return Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: '物资名称'),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(labelText: '物资编码'),
                      validator: _required,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey(_categoryId),
                            initialValue: _categoryId,
                            decoration: const InputDecoration(labelText: '分类'),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('未分类'),
                              ),
                              for (final group in groups)
                                DropdownMenuItem<int?>(
                                  value: group.id,
                                  child: Text(group.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _categoryId = value),
                          ),
                        ),
                        IconButton(
                          key: const Key('inventory-category-add'),
                          tooltip: '新增分类',
                          onPressed: _createCategory,
                          icon: const Icon(Icons.create_new_folder_outlined),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: _model,
                      decoration: const InputDecoration(labelText: '型号 / 规格'),
                    ),
                    TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: '单位'),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(labelText: '存放位置'),
                    ),
                    TextFormField(
                      controller: _minStock,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '最低库存'),
                      validator: _nonNegative,
                    ),
                    TextFormField(
                      controller: _maxStock,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '最高库存（可选）'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? null
                          : _nonNegative(value),
                    ),
                    TextFormField(
                      controller: _source,
                      decoration: const InputDecoration(labelText: '默认来源'),
                    ),
                    TextFormField(
                      controller: _remark,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: '备注'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('启用库存预警'),
                    value: _warningEnabled,
                    onChanged: (value) =>
                        setState(() => _warningEnabled = value),
                  ),
                  SwitchListTile(
                    title: const Text('常用物资'),
                    value: _common,
                    onChanged: (value) => setState(() => _common = value),
                  ),
                  if (widget.materialId != null)
                    ListTile(
                      title: const Text('物资状态'),
                      trailing: DropdownButton<String>(
                        value: _status,
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('启用')),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('停用'),
                          ),
                          DropdownMenuItem(value: 'retired', child: Text('淘汰')),
                        ],
                        onChanged: (value) =>
                            setState(() => _status = value ?? _status),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('inventory-material-submit'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '正在保存…' : '保存物资'),
            ),
          ],
        ),
      );
    }

    if (_material == null) return formContent(null);
    return FutureBuilder<InventoryMaterial?>(
      future: _material,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InventoryErrorState(onRetry: () => setState(() {}));
        }
        if (!snapshot.hasData) return const InventoryLoadingState();
        return formContent(snapshot.data);
      },
    );
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? '必填' : null;
String? _nonNegative(String? value) {
  final number = double.tryParse(value ?? '');
  return number == null || number < 0 ? '请输入大于或等于 0 的数字' : null;
}

String? _optional(String value) => value.trim().isEmpty ? null : value.trim();
