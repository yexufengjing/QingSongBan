import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../data/tire_repository.dart';
import '../domain/condition_options.dart';
import '../domain/tire_options.dart';
import 'vehicle_visual_view.dart';

class VehicleConditionTab extends ConsumerWidget {
  const VehicleConditionTab({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditions = ref.watch(vehicleConditionItemsProvider(vehicle.id));
    final installations = ref.watch(
      vehicleTireInstallationsProvider(vehicle.id),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _ConditionIntro(
          issueCount:
              conditions.valueOrNull
                  ?.where(
                    (item) => item.status != VehicleConditionStatus.normal,
                  )
                  .length ??
              0,
        ),
        const SizedBox(height: 10),
        VehicleVisualView(
          vehicle: vehicle,
          conditions: conditions.valueOrNull ?? const [],
        ),
        const SizedBox(height: 12),
        conditions.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) => _ConditionIssues(
            items: items,
            onInspect: (item) => _editCondition(
              context,
              ref,
              item.componentType,
              item.componentKey,
              item,
            ),
            onRepair: () => context.push('/vehicles/${vehicle.id}/repair/new'),
          ),
        ),
        const SizedBox(height: 12),
        conditions.when(
          loading: () => const _LoadingCard(),
          error: (error, _) => _ErrorCard(message: error.toString()),
          data: (items) => _ConditionList(
            vehicle: vehicle,
            items: items,
            onEdit: (componentType, componentKey, current) => _editCondition(
              context,
              ref,
              componentType,
              componentKey,
              current,
            ),
          ),
        ),
        const SizedBox(height: 14),
        installations.when(
          loading: () => const _LoadingCard(),
          error: (error, _) => _ErrorCard(message: error.toString()),
          data: (items) =>
              _TireSection(vehicleId: vehicle.id, installations: items),
        ),
      ],
    );
  }

  Future<void> _editCondition(
    BuildContext context,
    WidgetRef ref,
    String componentType,
    String componentKey,
    VehicleConditionItem? current,
  ) async {
    var status = current?.status ?? VehicleConditionStatus.normal;
    final detailController = TextEditingController(text: current?.detail ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            '${VehicleConditionOptions.componentLabel(componentType)}状态',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<VehicleConditionStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: '状态'),
                  items: [
                    for (final value in VehicleConditionStatus.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(VehicleConditionOptions.statusLabel(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => status = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '问题或处理备注',
                    hintText: '例如：发动机异响，待进一步检查',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    final detail = detailController.text;
    detailController.dispose();
    if (saved != true) return;
    await ref
        .read(vehicleConditionRepositoryProvider)
        .save(
          VehicleConditionDraft(
            vehicleId: vehicle.id,
            componentType: componentType,
            componentKey: componentKey,
            status: status,
            observedAt: DateTime.now(),
            detail: detail,
          ),
        );
  }
}

class _ConditionIssues extends StatelessWidget {
  const _ConditionIssues({
    required this.items,
    required this.onInspect,
    required this.onRepair,
  });

  final List<VehicleConditionItem> items;
  final void Function(VehicleConditionItem) onInspect;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final issues =
        items
            .where(
              (item) =>
                  item.status != VehicleConditionStatus.normal &&
                  item.status != VehicleConditionStatus.unavailable,
            )
            .toList()
          ..sort((a, b) => _severity(b.status).compareTo(_severity(a.status)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前发现问题 (${issues.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (issues.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '暂无需要处理的部件问题',
                  style: TextStyle(color: AppColors.body, fontSize: 13),
                ),
              ),
            for (final issue in issues) ...[
              const Divider(height: 12),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _conditionColor(issue.status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.build_outlined,
                      color: _conditionColor(issue.status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          VehicleConditionOptions.componentLabel(
                            issue.componentType,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          issue.detail?.isNotEmpty == true
                              ? issue.detail!
                              : VehicleConditionOptions.statusLabel(
                                  issue.status,
                                ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.body,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => onInspect(issue),
                    child: const Text('详情'),
                  ),
                  IconButton(
                    tooltip: '转报修',
                    onPressed: onRepair,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.techBlue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static int _severity(VehicleConditionStatus status) => switch (status) {
    VehicleConditionStatus.pendingRepair => 4,
    VehicleConditionStatus.repairing => 3,
    VehicleConditionStatus.needsAttention => 2,
    VehicleConditionStatus.minorAbnormal => 1,
    _ => 0,
  };
}

class _ConditionIntro extends StatelessWidget {
  const _ConditionIntro({required this.issueCount});

  final int issueCount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('部件车况', style: Theme.of(context).textTheme.titleLarge),
      const Spacer(),
      Icon(
        issueCount == 0
            ? Icons.check_circle_outline
            : Icons.warning_amber_outlined,
        color: issueCount == 0 ? AppColors.primary : AppColors.danger,
        size: 17,
      ),
      const SizedBox(width: 4),
      Text(
        issueCount == 0 ? '暂无异常' : '$issueCount 项异常',
        style: TextStyle(
          fontSize: 12,
          color: issueCount == 0 ? AppColors.primary : AppColors.danger,
        ),
      ),
    ],
  );
}

class _ConditionList extends StatelessWidget {
  const _ConditionList({
    required this.vehicle,
    required this.items,
    required this.onEdit,
  });

  final Vehicle vehicle;
  final List<VehicleConditionItem> items;
  final void Function(String, String, VehicleConditionItem?) onEdit;

  @override
  Widget build(BuildContext context) {
    final components = <(String, String)>[
      ('engine', 'engineMain'),
      ('light', 'lighting'),
      ('brake', 'brakeMain'),
      ('water', 'waterMain'),
      ('hydraulic', 'hydraulicMain'),
      ('electrical', 'electricalMain'),
      ('exterior', 'exteriorMain'),
      if (vehicle.vehicleType == VehicleType.sweeper)
        ('sweeper', 'sweeperMain'),
    ];
    final itemByKey = <String, VehicleConditionItem>{
      for (final item in items)
        '${item.componentType}:${item.componentKey}': item,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('部件清单', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final component in components)
              _ConditionRow(
                title: VehicleConditionOptions.componentLabel(component.$1),
                item: itemByKey['${component.$1}:${component.$2}'],
                onTap: () => onEdit(
                  component.$1,
                  component.$2,
                  itemByKey['${component.$1}:${component.$2}'],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.title,
    required this.item,
    required this.onTap,
  });

  final String title;
  final VehicleConditionItem? item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = item?.status;
    final color = status == null
        ? const Color(0xff96a2ad)
        : _conditionColor(status);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, color: color, size: 14),
      title: Text(title),
      subtitle: Text(
        item?.detail?.isNotEmpty == true ? item!.detail! : '尚未填写详细记录',
      ),
      trailing: TextButton(
        onPressed: onTap,
        child: Text(
          status == null
              ? '未记录'
              : VehicleConditionOptions.statusShortLabel(status),
          style: TextStyle(color: color),
        ),
      ),
    );
  }
}

class _TireSection extends StatelessWidget {
  const _TireSection({required this.vehicleId, required this.installations});

  final int vehicleId;
  final List<TireInstallation> installations;

  @override
  Widget build(BuildContext context) {
    final byPosition = {for (final item in installations) item.position: item};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '六轮位',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text('驾驶员视角左右', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Tire>>(
              future: _loadTires(context),
              builder: (context, snapshot) {
                final tires = {
                  for (final tire in snapshot.data ?? <Tire>[]) tire.id: tire,
                };
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    for (final position in TirePosition.values)
                      _TirePositionCard(
                        position: position,
                        installation: byPosition[position],
                        tire: tires[byPosition[position]?.tireId],
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

  Future<List<Tire>> _loadTires(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    return container.read(tireRepositoryProvider).listAssets();
  }
}

class _TirePositionCard extends StatelessWidget {
  const _TirePositionCard({
    required this.position,
    this.installation,
    this.tire,
  });

  final TirePosition position;
  final TireInstallation? installation;
  final Tire? tire;

  @override
  Widget build(BuildContext context) {
    final installed = installation != null;
    return Card(
      color: installed ? AppColors.lightBlue : AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TireOptions.positionLabel(position),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              installed
                  ? (tire?.tireNo ?? '轮胎 #${installation!.tireId}')
                  : '未配置',
            ),
            if (installed)
              Text(
                '连续 ${TireRepository.usageDays(installation!)} 天',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

Color _conditionColor(VehicleConditionStatus status) => switch (status) {
  VehicleConditionStatus.normal => AppColors.primary,
  VehicleConditionStatus.minorAbnormal ||
  VehicleConditionStatus.needsAttention => Colors.orange,
  VehicleConditionStatus.pendingRepair ||
  VehicleConditionStatus.repairing => AppColors.danger,
  VehicleConditionStatus.unavailable => AppColors.body,
};

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.lightDanger,
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: AppColors.danger),
      title: const Text('车况数据加载失败'),
      subtitle: Text(message),
    ),
  );
}
