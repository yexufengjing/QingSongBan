import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_widgets.dart';

class InventoryMaterialsPage extends ConsumerStatefulWidget {
  const InventoryMaterialsPage({super.key});

  @override
  ConsumerState<InventoryMaterialsPage> createState() =>
      _InventoryMaterialsPageState();
}

class _InventoryMaterialsPageState
    extends ConsumerState<InventoryMaterialsPage> {
  final _search = TextEditingController();
  bool _commonOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materials = ref.watch(inventoryMaterialsProvider);
    final categories =
        ref.watch(inventoryCategoriesProvider).valueOrNull ??
        const <InventoryCategory>[];
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('物资信息'),
        actions: [
          IconButton(
            tooltip: '新增物资',
            onPressed: () => context.push('/inventory/materials/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('inventory-material-add'),
        onPressed: () => context.push('/inventory/materials/new'),
        icon: const Icon(Icons.add),
        label: const Text('新增物资'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索名称、型号或编码',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF0F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    selected: _commonOnly,
                    label: const Text('常用物资'),
                    avatar: const Icon(Icons.star_outline, size: 18),
                    onSelected: (value) => setState(() => _commonOnly = value),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: materials.when(
              loading: () => const InventoryLoadingState(),
              error: (_, _) => InventoryErrorState(
                onRetry: () => ref.invalidate(inventoryMaterialsProvider),
              ),
              data: (items) {
                final keyword = _search.text.trim().toLowerCase();
                final filtered = items.where((item) {
                  final matchesKeyword =
                      keyword.isEmpty ||
                      item.materialName.toLowerCase().contains(keyword) ||
                      item.materialCode.toLowerCase().contains(keyword) ||
                      (item.modelSpec ?? '').toLowerCase().contains(keyword);
                  return matchesKeyword && (!_commonOnly || item.isCommon);
                }).toList();
                if (filtered.isEmpty) {
                  return InventoryEmptyState(
                    title: items.isEmpty ? '还没有物资' : '没有匹配的物资',
                    message: items.isEmpty
                        ? '添加物资档案后即可办理入库和领用。'
                        : '试试其他名称、型号或编码。',
                    action: items.isEmpty
                        ? FilledButton.icon(
                            onPressed: () =>
                                context.push('/inventory/materials/new'),
                            icon: const Icon(Icons.add),
                            label: const Text('新增物资'),
                          )
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(inventoryMaterialsProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final material = filtered[index];
                      return _MaterialCard(
                        material: material,
                        categoryName:
                            categoryNames[material.categoryId] ??
                            (material.categoryId == null ? '未分类' : '分类加载中'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material, required this.categoryName});

  final InventoryMaterial material;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final stockStatus = InventoryStockRow(material: material).status;
    final status = switch (stockStatus) {
      InventoryStockStatus.outOfStock => (label: '缺货', color: AppColors.danger),
      InventoryStockStatus.low => (
        label: '库存不足',
        color: const Color(0xFFE98500),
      ),
      InventoryStockStatus.normal => (label: '正常', color: AppColors.primary),
    };
    return Card(
      child: InkWell(
        key: Key('inventory-material-${material.id}'),
        onTap: () => context.push('/inventory/materials/${material.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 8, 14),
          child: Column(
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.materialName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${material.materialCode} · $categoryName',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '当前库存',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${material.currentStock} ${material.unitName}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: '物资操作',
                    onSelected: (value) {
                      if (value == 'edit') {
                        context.push(
                          '/inventory/materials/${material.id}/edit',
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑物资')),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnWidth = (constraints.maxWidth - 16) / 2;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: columnWidth,
                        child: _MaterialDatum(
                          label: '规格型号',
                          value: material.modelSpec ?? '未填写',
                        ),
                      ),
                      SizedBox(
                        width: columnWidth,
                        child: _MaterialDatum(
                          label: '单位',
                          value: material.unitName,
                        ),
                      ),
                      SizedBox(
                        width: columnWidth,
                        child: _MaterialDatum(
                          label: '最低库存',
                          value: '${material.minStock}',
                        ),
                      ),
                      SizedBox(
                        width: columnWidth,
                        child: _MaterialDatum(
                          label: '存放位置',
                          value: material.storageLocation ?? '未填写',
                        ),
                      ),
                      InventoryStatusChip(
                        label: material.status == 'active'
                            ? status.label
                            : '停用',
                        color: material.status == 'active'
                            ? status.color
                            : AppColors.helper,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialDatum extends StatelessWidget {
  const _MaterialDatum({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}
