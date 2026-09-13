import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../application/personnel_providers.dart';
import '../domain/personnel_options.dart';
import 'personnel_widgets.dart';

class PersonnelListPage extends ConsumerStatefulWidget {
  const PersonnelListPage({
    super.key,
    this.initialStatus,
    this.initialHireMonth,
  });

  final EmployeeStatus? initialStatus;
  final String? initialHireMonth;

  @override
  ConsumerState<PersonnelListPage> createState() => _PersonnelListPageState();
}

class _PersonnelListPageState extends ConsumerState<PersonnelListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(personnelSearchQueryProvider.notifier).state = '';
      ref.read(personnelStatusFilterProvider.notifier).state =
          widget.initialStatus;
      ref.read(personnelAttendanceGroupFilterProvider.notifier).state = null;
      ref.read(personnelEmploymentTypeFilterProvider.notifier).state = null;
      ref.read(personnelHireMonthFilterProvider.notifier).state =
          widget.initialHireMonth;
      ref.read(personnelShowDeletedProvider.notifier).state = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(personnelListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('人员名单'),
        actions: [
          IconButton(
            onPressed: () => context.push('/personnel/new'),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: '新增人员',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _PersonnelFilters(),
            Expanded(
              child: employees.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => PersonnelErrorState(
                  onRetry: () => ref.invalidate(personnelListProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return PersonnelEmptyState(
                      onCreate: () => context.push('/personnel/new'),
                    );
                  }
                  return _EmployeeList(employees: items);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonnelFilters extends ConsumerWidget {
  const _PersonnelFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(personnelSearchQueryProvider);
    final status = ref.watch(personnelStatusFilterProvider);
    final groupId = ref.watch(personnelAttendanceGroupFilterProvider);
    final employmentType = ref.watch(personnelEmploymentTypeFilterProvider);
    final hireMonth = ref.watch(personnelHireMonthFilterProvider);
    final showDeleted = ref.watch(personnelShowDeletedProvider);
    final allEmployees = ref
        .watch(allPersonnelProvider)
        .maybeWhen(data: (items) => items, orElse: () => const <Employee>[]);
    final groups = ref
        .watch(attendanceGroupsProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => const <AttendanceGroup>[],
        );
    final employmentTypes = <String>{
      ...PersonnelOptions.employmentTypes,
      for (final employee in allEmployees)
        if (employee.employmentType?.isNotEmpty ?? false)
          employee.employmentType!,
    }.toList();
    final selectedGroupId =
        groupId != null && groups.any((group) => group.id == groupId)
        ? groupId
        : 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          children: [
            TextField(
              onChanged: (value) =>
                  ref.read(personnelSearchQueryProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: '搜索姓名、编号、岗位或班组',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () =>
                            ref
                                    .read(personnelSearchQueryProvider.notifier)
                                    .state =
                                '',
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChoiceChip(
                    label: '全部状态',
                    selected: status == null,
                    onSelected: (_) =>
                        ref.read(personnelStatusFilterProvider.notifier).state =
                            null,
                  ),
                  for (final option in EmployeeStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChoiceChip(
                        label: PersonnelOptions.statusLabel(option),
                        selected: status == option,
                        onSelected: (_) =>
                            ref
                                    .read(
                                      personnelStatusFilterProvider.notifier,
                                    )
                                    .state =
                                option,
                      ),
                    ),
                ],
              ),
            ),
            if (hireMonth != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: const Icon(Icons.event_outlined, size: 17),
                  label: Text('入职月份：$hireMonth'),
                  onDeleted: () =>
                      ref
                              .read(personnelHireMonthFilterProvider.notifier)
                              .state =
                          null,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedGroupId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '考勤组',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('全部考勤组')),
                      for (final group in groups)
                        DropdownMenuItem(
                          value: group.id,
                          child: Text(group.name),
                        ),
                    ],
                    onChanged: (value) =>
                        ref
                            .read(
                              personnelAttendanceGroupFilterProvider.notifier,
                            )
                            .state = value == null || value == 0
                        ? null
                        : value,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: employmentType ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '用工类型',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部类型')),
                      for (final type in employmentTypes)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: (value) =>
                        ref
                            .read(
                              personnelEmploymentTypeFilterProvider.notifier,
                            )
                            .state = value == null || value.isEmpty
                        ? null
                        : value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                selected: showDeleted,
                onSelected: (value) =>
                    ref.read(personnelShowDeletedProvider.notifier).state =
                        value,
                avatar: const Icon(Icons.restore_from_trash_outlined, size: 17),
                label: const Text('显示已删除档案'),
                selectedColor: AppColors.lightDanger,
                checkmarkColor: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.lightGreen,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: selected ? AppColors.primary : AppColors.body,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      itemCount: employees.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '找到 ${employees.length} 条档案',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return _EmployeeListTile(employee: employees[index - 1]);
      },
    );
  }
}

class _EmployeeListTile extends StatelessWidget {
  const _EmployeeListTile({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (employee.position?.isNotEmpty ?? false) employee.position!,
      if (employee.team?.isNotEmpty ?? false) employee.team!,
      if (employee.workArea?.isNotEmpty ?? false) employee.workArea!,
    ];
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/personnel/${employee.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: employee.isDeleted
                      ? AppColors.lightDanger
                      : AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  employee.isDeleted
                      ? Icons.person_off_outlined
                      : Icons.person_outline,
                  color: employee.isDeleted
                      ? AppColors.danger
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            employee.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        EmployeeStatusBadge(
                          status: employee.status,
                          deleted: employee.isDeleted,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${employee.employeeNo} · ${subtitleParts.isEmpty ? '岗位未填写' : subtitleParts.join(' · ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '入职 ${AppDateUtils.formatDate(employee.hireDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.helper),
            ],
          ),
        ),
      ),
    );
  }
}
