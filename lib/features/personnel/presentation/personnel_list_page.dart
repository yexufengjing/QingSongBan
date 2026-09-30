import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../insurance/application/insurance_providers.dart';
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
      appBar: AppBar(title: const Text('人员名单'), centerTitle: true),
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
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          key: const Key('personnel-add-fab'),
          onPressed: () => context.push('/personnel/new'),
          tooltip: '新增人员',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add_alt_1_outlined, size: 18),
              SizedBox(height: 2),
              Text(
                '新增人员',
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: 11, height: 1),
              ),
            ],
          ),
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
    final allEmployees = ref
        .watch(allPersonnelProvider)
        .maybeWhen(data: (items) => items, orElse: () => const <Employee>[]);
    final groupsState = ref.watch(attendanceGroupsProvider);
    final groups = groupsState.valueOrNull ?? const <AttendanceGroup>[];
    final selectedGroupId = ref.watch(personnelAttendanceGroupFilterProvider);
    final activeCount = allEmployees
        .where((item) => item.status == EmployeeStatus.active)
        .length;
    final pausedCount = allEmployees
        .where((item) => item.status == EmployeeStatus.paused)
        .length;
    final terminatedCount = allEmployees
        .where((item) => item.status == EmployeeStatus.terminated)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) =>
                      ref.read(personnelSearchQueryProvider.notifier).state =
                          value,
                  decoration: InputDecoration(
                    hintText: '搜索姓名、人员编号、岗位或班组',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () =>
                                ref
                                        .read(
                                          personnelSearchQueryProvider.notifier,
                                        )
                                        .state =
                                    '',
                            icon: const Icon(Icons.clear),
                            tooltip: '清除搜索',
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _PersonnelAdvancedFilters(),
                ),
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('筛选'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: const BorderSide(color: AppColors.divider),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatusChip(
                label: '全部',
                count: allEmployees.length,
                selected: status == null,
                onSelected: () =>
                    ref.read(personnelStatusFilterProvider.notifier).state =
                        null,
              ),
              _StatusChip(
                label: '在岗',
                count: activeCount,
                selected: status == EmployeeStatus.active,
                onSelected: () =>
                    ref.read(personnelStatusFilterProvider.notifier).state =
                        EmployeeStatus.active,
              ),
              _StatusChip(
                label: '暂停工作',
                count: pausedCount,
                selected: status == EmployeeStatus.paused,
                onSelected: () =>
                    ref.read(personnelStatusFilterProvider.notifier).state =
                        EmployeeStatus.paused,
              ),
              _StatusChip(
                label: '已离职',
                count: terminatedCount,
                selected: status == EmployeeStatus.terminated,
                onSelected: () =>
                    ref.read(personnelStatusFilterProvider.notifier).state =
                        EmployeeStatus.terminated,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: groups.any((group) => group.id == selectedGroupId)
                        ? selectedGroupId
                        : 0,
                    isDense: true,
                    iconSize: 18,
                    borderRadius: BorderRadius.circular(10),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('全部班组', style: TextStyle(fontSize: 13)),
                      ),
                      for (final group in groups)
                        DropdownMenuItem(
                          value: group.id,
                          child: Text(
                            group.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: groupsState.isLoading || groupsState.hasError
                        ? null
                        : (value) =>
                              ref
                                  .read(
                                    personnelAttendanceGroupFilterProvider
                                        .notifier,
                                  )
                                  .state = value == null || value == 0
                              ? null
                              : value,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: groupsState.when(
                  loading: () => const Text(
                    '班组加载中',
                    style: TextStyle(fontSize: 12, color: AppColors.helper),
                  ),
                  error: (_, _) => const Text(
                    '班组暂不可用',
                    style: TextStyle(fontSize: 12, color: AppColors.helper),
                  ),
                  data: (items) => items.isEmpty
                      ? const Text(
                          '暂无考勤组',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.helper,
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final group in items)
                                _AttendanceGroupChip(
                                  label: group.name,
                                  selected: selectedGroupId == group.id,
                                  onSelected: () =>
                                      ref
                                          .read(
                                            personnelAttendanceGroupFilterProvider
                                                .notifier,
                                          )
                                          .state = group
                                          .id,
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ChoiceChip(
        label: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(fontSize: 11),
              ),
              Text('$count', maxLines: 1, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.lightBlue,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.ink,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        labelPadding: EdgeInsets.zero,
      ),
    ),
  );
}

class _AttendanceGroupChip extends StatelessWidget {
  const _AttendanceGroupChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: AppColors.lightGreen,
      backgroundColor: AppColors.lightBlue,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.ink,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: selected
          ? const BorderSide(color: AppColors.primary)
          : BorderSide.none,
      visualDensity: VisualDensity.compact,
    ),
  );
}

class _PersonnelAdvancedFilters extends ConsumerWidget {
  const _PersonnelAdvancedFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroupId = ref.watch(personnelAttendanceGroupFilterProvider);
    final showDeleted = ref.watch(personnelShowDeletedProvider);
    final hireMonth = ref.watch(personnelHireMonthFilterProvider);
    final employmentType = ref.watch(personnelEmploymentTypeFilterProvider);
    final allEmployees = ref
        .watch(allPersonnelProvider)
        .maybeWhen(data: (items) => items, orElse: () => const <Employee>[]);
    final types = <String>{
      ...PersonnelOptions.employmentTypes,
      for (final employee in allEmployees)
        if (employee.employmentType?.isNotEmpty ?? false)
          employee.employmentType!,
    }.toList();
    final groups = ref
        .watch(attendanceGroupsProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => const <AttendanceGroup>[],
        );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('筛选人员', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: groups.any((group) => group.id == selectedGroupId)
                  ? selectedGroupId
                  : 0,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '考勤组',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              items: [
                const DropdownMenuItem(value: 0, child: Text('全部考勤组')),
                for (final group in groups)
                  DropdownMenuItem(value: group.id, child: Text(group.name)),
              ],
              onChanged: (value) =>
                  ref
                      .read(personnelAttendanceGroupFilterProvider.notifier)
                      .state = value == null || value == 0
                  ? null
                  : value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  employmentType != null && types.contains(employmentType)
                  ? employmentType
                  : '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '用工类型',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部用工类型')),
                for (final type in types)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) =>
                  ref
                      .read(personnelEmploymentTypeFilterProvider.notifier)
                      .state = value == null || value.isEmpty
                  ? null
                  : value,
            ),
            if (hireMonth != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
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
            const SizedBox(height: 6),
            FilterChip(
              selected: showDeleted,
              onSelected: (value) =>
                  ref.read(personnelShowDeletedProvider.notifier).state = value,
              avatar: const Icon(Icons.restore_from_trash_outlined, size: 17),
              label: const Text('显示已删除档案'),
              selectedColor: AppColors.lightDanger,
              checkmarkColor: AppColors.danger,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成筛选'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
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

class _EmployeeListTile extends ConsumerWidget {
  const _EmployeeListTile({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insuranceState = ref.watch(insuranceProfilesProvider);
    final insurance = insuranceState.valueOrNull
        ?.where((item) => item.employee.id == employee.id)
        .firstOrNull;
    final insuredLabel = insuranceState.when(
      loading: () => '加载中',
      error: (_, _) => '暂不可用',
      data: (_) => insurance == null
          ? '未设置'
          : insurance.profile.isInsured
          ? '已参保'
          : '未参保',
    );
    final insuredColor = insuranceState.hasError
        ? AppColors.helper
        : insuranceState.isLoading
        ? AppColors.helper
        : insurance?.profile.isInsured == true
        ? AppColors.primary
        : insurance == null
        ? AppColors.helper
        : AppColors.danger;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/personnel/${employee.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 44,
                decoration: BoxDecoration(
                  color: employee.isDeleted
                      ? AppColors.lightDanger
                      : AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  employee.isDeleted
                      ? Icons.person_off_outlined
                      : Icons.person_outline,
                  color: employee.isDeleted
                      ? AppColors.danger
                      : AppColors.techBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 5),
                        if (employee.gender == '女')
                          const Icon(
                            Icons.female,
                            size: 16,
                            color: Color(0xFFE05275),
                          )
                        else if (employee.gender == '男')
                          const Icon(
                            Icons.male,
                            size: 16,
                            color: AppColors.techBlue,
                          )
                        else
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: AppColors.helper,
                          ),
                        const Spacer(),
                        EmployeeStatusBadge(
                          status: employee.status,
                          deleted: employee.isDeleted,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '人员编号  ${employee.employeeNo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: _EmployeeField(
                            label: '岗位',
                            value: employee.position,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _EmployeeField(
                            label: '所属班组',
                            value: employee.team,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Expanded(
                          child: _EmployeeField(
                            label: '工作区域',
                            value: employee.workArea,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                '是否参保  ',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Flexible(
                                child: Text(
                                  insuredLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: insuredColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.helper,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeField extends StatelessWidget {
  const _EmployeeField({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('$label  ', style: const TextStyle(fontSize: 11, height: 1.25)),
      Expanded(
        child: Text(
          value?.isNotEmpty == true ? value! : '未填写',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            height: 1.25,
            color: AppColors.ink,
          ),
        ),
      ),
    ],
  );
}
