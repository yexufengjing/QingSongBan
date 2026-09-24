import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../domain/vehicle_options.dart';
import 'vehicle_navigation_bar.dart';

class VehicleArchivePage extends ConsumerWidget {
  const VehicleArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);
    final selectedType = ref.watch(vehicleTypeFilterProvider);
    final selectedStatus = ref.watch(vehicleStatusFilterProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('车辆档案'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/vehicles/new'),
            style: TextButton.styleFrom(foregroundColor: AppColors.techBlue),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('新增车辆'),
          ),
        ],
      ),
      bottomNavigationBar: const VehicleNavigationBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          TextField(
            onChanged: (value) =>
                ref.read(vehicleSearchQueryProvider.notifier).state = value,
            decoration: InputDecoration(
              hintText: '搜索车牌号、车辆名称、编号或负责人',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final type in [
                null,
                VehicleType.sweeper,
                VehicleType.waterTruck,
              ]) ...[
                if (type != null) const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        type == null
                            ? '全部'
                            : VehicleOptions.typeShortLabel(type),
                      ),
                    ),
                    selected: selectedType == type,
                    showCheckmark: false,
                    selectedColor: AppColors.techBlue,
                    labelStyle: TextStyle(
                      color: selectedType == type
                          ? Colors.white
                          : AppColors.body,
                    ),
                    side: BorderSide.none,
                    onSelected: (_) =>
                        ref.read(vehicleTypeFilterProvider.notifier).state =
                            type,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('车辆状态', style: TextStyle(color: AppColors.body)),
              const SizedBox(width: 10),
              DropdownButton<VehicleStatus?>(
                value: selectedStatus,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem<VehicleStatus?>(
                    value: null,
                    child: Text('全部'),
                  ),
                  for (final status in VehicleStatus.values)
                    DropdownMenuItem<VehicleStatus?>(
                      value: status,
                      child: Text(VehicleOptions.statusLabel(status)),
                    ),
                ],
                onChanged: (status) =>
                    ref.read(vehicleStatusFilterProvider.notifier).state =
                        status,
              ),
              const Spacer(),
              vehicles.when(
                data: (items) => Text(
                  '共 ${items.length} 辆',
                  style: const TextStyle(color: AppColors.body),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          vehicles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('车辆档案加载失败：$error'),
            data: (items) => items.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('没有符合条件的车辆'),
                    ),
                  )
                : Column(
                    children: [
                      for (final vehicle in items) ...[
                        _ArchiveCard(vehicle: vehicle),
                        const SizedBox(height: 9),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final statusColor = vehicleStatusColor(vehicle.status);
    final purchaseDate = vehicle.purchaseDate;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/vehicles/${vehicle.id}'),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              SizedBox(
                width: 93,
                height: 94,
                child: Image.asset(
                  vehicle.vehicleType == VehicleType.sweeper
                      ? 'assets/vehicles/sweeper-truck.png'
                      : 'assets/vehicles/water-truck.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _ArchiveStatus(
                          label: VehicleOptions.statusLabel(vehicle.status),
                          color: statusColor,
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.helper,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${VehicleOptions.typeShortLabel(vehicle.vehicleType)}  ·  ${vehicle.licensePlate ?? '未录车牌'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.techBlue,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DetailLine(
                      '编号',
                      vehicle.vehicleNo,
                      '品牌型号',
                      [vehicle.brand, vehicle.model]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' '),
                    ),
                    const SizedBox(height: 5),
                    _DetailLine(
                      '区域',
                      vehicle.workArea ?? '—',
                      '责任人',
                      vehicle.responsiblePerson ?? '—',
                    ),
                    const SizedBox(height: 5),
                    _DetailLine(
                      '部门',
                      vehicle.department ?? '—',
                      '购置日期',
                      purchaseDate == null
                          ? '—'
                          : '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label1, this.value1, this.label2, this.value2);

  final String label1;
  final String value1;
  final String label2;
  final String value2;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          '$label1  ${value1.isEmpty ? '—' : value1}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.body),
        ),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          '$label2  ${value2.isEmpty ? '—' : value2}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.body),
        ),
      ),
    ],
  );
}

class _ArchiveStatus extends StatelessWidget {
  const _ArchiveStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
    ),
  );
}
