import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../domain/vehicle_options.dart';
import 'vehicle_navigation_bar.dart';

class VehicleArchivePage extends ConsumerStatefulWidget {
  const VehicleArchivePage({super.key});

  @override
  ConsumerState<VehicleArchivePage> createState() => _VehicleArchivePageState();
}

class _VehicleArchivePageState extends ConsumerState<VehicleArchivePage> {
  String? _selectedArea;
  _ArchiveSort _sort = _ArchiveSort.defaultOrder;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final vehicles = ref.watch(vehicleListProvider);
    final allVehicles = ref.watch(allVehiclesProvider);
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          TextField(
            onChanged: (value) =>
                ref.read(vehicleSearchQueryProvider.notifier).state = value,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: '搜索车牌号、车辆名称、编号或负责人',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(width: 1),
                    ),
                    TextButton(
                      onPressed: () => FocusScope.of(context).unfocus(),
                      child: const Text('搜索'),
                    ),
                  ],
                ),
              ),
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
          allVehicles.when(
            loading: () => const SizedBox(height: 48),
            error: (_, _) => const SizedBox.shrink(),
            data: (allItems) {
              final areas =
                  allItems
                      .map((vehicle) => vehicle.workArea?.trim())
                      .whereType<String>()
                      .where((area) => area.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
              if (_selectedArea != null && !areas.contains(_selectedArea)) {
                _selectedArea = null;
              }
              return Row(
                children: [
                  Expanded(
                    child: _ArchiveFilter(
                      label: '车型',
                      value: selectedType,
                      items: [
                        (null, '全部'),
                        for (final type in VehicleType.values)
                          (type, VehicleOptions.typeShortLabel(type)),
                      ],
                      onChanged: (type) =>
                          ref.read(vehicleTypeFilterProvider.notifier).state =
                              type,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ArchiveFilter(
                      label: '状态',
                      value: selectedStatus,
                      items: [
                        (null, '全部'),
                        for (final status in VehicleStatus.values)
                          (status, VehicleOptions.statusLabel(status)),
                      ],
                      onChanged: (status) =>
                          ref.read(vehicleStatusFilterProvider.notifier).state =
                              status,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ArchiveFilter<String>(
                      label: '区域',
                      value: _selectedArea,
                      items: [
                        (null, '全部'),
                        for (final area in areas) (area, area),
                      ],
                      onChanged: (area) => setState(() => _selectedArea = area),
                    ),
                  ),
                ],
              );
            },
          ),
          vehicles.when(
            data: (items) {
              final count = _selectedArea == null
                  ? items.length
                  : items
                        .where((vehicle) => vehicle.workArea == _selectedArea)
                        .length;
              return Row(
                children: [
                  Text(
                    '共 $count 辆',
                    style: const TextStyle(color: AppColors.body, fontSize: 12),
                  ),
                  const Spacer(),
                  PopupMenuButton<_ArchiveSort>(
                    tooltip: '排序车辆',
                    initialValue: _sort,
                    onSelected: (sort) => setState(() => _sort = sort),
                    itemBuilder: (context) => [
                      for (final sort in _ArchiveSort.values)
                        CheckedPopupMenuItem(
                          value: sort,
                          checked: _sort == sort,
                          child: Text(sort.label),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.swap_vert,
                            size: 16,
                            color: AppColors.body,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sort.label,
                            style: const TextStyle(
                              color: AppColors.body,
                              fontSize: 12,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.body,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          vehicles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('车辆档案加载失败：$error'),
            data: (items) {
              final visibleItems =
                  (_selectedArea == null
                          ? items
                          : items
                                .where(
                                  (vehicle) =>
                                      vehicle.workArea == _selectedArea,
                                )
                                .toList())
                      .toList();
              switch (_sort) {
                case _ArchiveSort.defaultOrder:
                  break;
                case _ArchiveSort.name:
                  visibleItems.sort((a, b) => a.name.compareTo(b.name));
                case _ArchiveSort.vehicleNo:
                  visibleItems.sort(
                    (a, b) => a.vehicleNo.compareTo(b.vehicleNo),
                  );
                case _ArchiveSort.status:
                  visibleItems.sort(
                    (a, b) => a.status.index.compareTo(b.status.index),
                  );
              }
              return visibleItems.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('没有符合条件的车辆'),
                      ),
                    )
                  : Column(
                      children: [
                        for (final vehicle in visibleItems) ...[
                          _ArchiveCard(vehicle: vehicle),
                          const SizedBox(height: 9),
                        ],
                      ],
                    );
            },
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
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: _ArchiveInfoCell(
                            icon: Icons.description,
                            label: '车辆编号',
                            value: vehicle.vehicleNo,
                          ),
                        ),
                        Expanded(
                          child: _ArchiveInfoCell(
                            icon: Icons.inventory_2,
                            label: '品牌型号',
                            value: [vehicle.brand, vehicle.model]
                                .whereType<String>()
                                .where((value) => value.isNotEmpty)
                                .join(' '),
                          ),
                        ),
                        Expanded(
                          child: _ArchiveInfoCell(
                            icon: Icons.calendar_month,
                            label: '购置日期',
                            value: purchaseDate == null
                                ? '—'
                                : '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _ArchiveInfoCell(
                            icon: Icons.location_on,
                            label: '区域',
                            value: vehicle.workArea ?? '—',
                          ),
                        ),
                        Expanded(
                          child: _ArchiveInfoCell(
                            icon: Icons.person,
                            label: '责任人',
                            value: vehicle.responsiblePerson ?? '—',
                          ),
                        ),
                        Expanded(
                          child: _ArchiveInfoCell(
                            icon: Icons.apartment,
                            label: '所属部门',
                            value: vehicle.department ?? '—',
                          ),
                        ),
                      ],
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

class _ArchiveFilter<T> extends StatelessWidget {
  const _ArchiveFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<(T?, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider.withValues(alpha: .65)),
    ),
    child: Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.body, fontSize: 13),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: DropdownButton<T?>(
            isExpanded: true,
            value: value,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.ink, fontSize: 13),
            items: [
              for (final item in items)
                DropdownMenuItem<T?>(
                  value: item.$1,
                  child: Text(item.$2, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class _ArchiveInfoCell extends StatelessWidget {
  const _ArchiveInfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: AppColors.helper),
      const SizedBox(width: 4),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.body),
            ),
            Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700),
    ),
  );
}

enum _ArchiveSort {
  defaultOrder('默认排序'),
  name('按名称'),
  vehicleNo('按编号'),
  status('按状态');

  const _ArchiveSort(this.label);
  final String label;
}
