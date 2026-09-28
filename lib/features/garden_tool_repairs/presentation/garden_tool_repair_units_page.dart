import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/garden_tool_repair_providers.dart';

class GardenToolRepairUnitsPage extends ConsumerWidget {
  const GardenToolRepairUnitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(gardenToolRepairUnitsProvider(true));
    return Scaffold(
      appBar: AppBar(title: const Text('维修单位')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editUnit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新增单位'),
      ),
      body: units.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('单位数据加载失败：$error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('暂无维修单位，请先新增'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final unit = items[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: unit.isActive
                            ? AppColors.lightBlue
                            : AppColors.background,
                        child: Icon(
                          Icons.apartment,
                          color: unit.isActive
                              ? AppColors.techBlue
                              : AppColors.helper,
                        ),
                      ),
                      title: Text(unit.name),
                      subtitle: Text(unit.isActive ? '启用中' : '已停用'),
                      trailing: PopupMenuButton<_UnitAction>(
                        onSelected: (action) async {
                          if (action == _UnitAction.edit) {
                            await _editUnit(context, ref, unit: unit);
                          } else {
                            await ref
                                .read(gardenToolRepairRepositoryProvider)
                                .saveUnit(
                                  id: unit.id,
                                  name: unit.name,
                                  sortOrder: unit.sortOrder,
                                  isActive: !unit.isActive,
                                );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _UnitAction.edit,
                            child: Text('编辑名称'),
                          ),
                          PopupMenuItem(
                            value: _UnitAction.toggle,
                            child: Text(unit.isActive ? '停用' : '启用'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _editUnit(
    BuildContext context,
    WidgetRef ref, {
    GardenToolRepairUnit? unit,
  }) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _UnitNameDialog(
        title: unit == null ? '新增维修单位' : '编辑维修单位',
        initialName: unit?.name ?? '',
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref
          .read(gardenToolRepairRepositoryProvider)
          .saveUnit(
            id: unit?.id,
            name: name,
            sortOrder: unit?.sortOrder ?? 0,
            isActive: unit?.isActive ?? true,
          );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }
}

class _UnitNameDialog extends StatefulWidget {
  const _UnitNameDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_UnitNameDialog> createState() => _UnitNameDialogState();
}

class _UnitNameDialogState extends State<_UnitNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: '单位名称'),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );
}

enum _UnitAction { edit, toggle }
