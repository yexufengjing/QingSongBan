import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../../personnel/domain/personnel_options.dart';
import '../application/monthly_roster_providers.dart';
import '../domain/monthly_roster_options.dart';

class MonthlyRosterPage extends ConsumerWidget {
  const MonthlyRosterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(monthlyRosterGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('月度考勤名单'),
        actions: [
          IconButton(
            onPressed: () => context.push('/attendance/groups'),
            icon: const Icon(Icons.groups_outlined),
            tooltip: '考勤组管理',
          ),
        ],
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _RosterError(
          onRetry: () => ref.invalidate(monthlyRosterGroupsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _NoAttendanceGroup(
              onManage: () => context.push('/attendance/groups'),
            );
          }
          return _RosterContent(groups: items);
        },
      ),
    );
  }
}

class _RosterContent extends ConsumerWidget {
  const _RosterContent({required this.groups});

  final List<AttendanceGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(monthlyRosterMonthProvider);
    final selectedId = ref.watch(monthlyRosterGroupIdProvider);
    final selectedGroup = groups.firstWhere(
      (group) => group.id == selectedId,
      orElse: () => groups.first,
    );
    if (selectedId == null || !groups.any((group) => group.id == selectedId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(monthlyRosterGroupIdProvider) != selectedGroup.id) {
          ref.read(monthlyRosterGroupIdProvider.notifier).state =
              selectedGroup.id;
        }
      });
    }

    final entries = ref.watch(monthlyRosterEntriesProvider);
    final counts = ref.watch(monthlyRosterCountsProvider);
    final showRemoved = ref.watch(monthlyRosterShowRemovedProvider);
    final canEdit = selectedGroup.isEnabled;
    final activeEntries = entries.maybeWhen(
      data: (items) => items.where((item) => item.roster.isActive).toList(),
      orElse: () => const <MonthlyRosterEntryView>[],
    );
    final activeIds = activeEntries.map((item) => item.employee.id).toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _RosterHero(month: month, group: selectedGroup),
        const SizedBox(height: 14),
        _RosterSelectors(
          month: month,
          groups: groups,
          selectedGroup: selectedGroup,
          onMonthChanged: (value) =>
              ref.read(monthlyRosterMonthProvider.notifier).state = value,
          onGroupChanged: (value) {
            if (value != null) {
              ref.read(monthlyRosterGroupIdProvider.notifier).state = value;
            }
          },
        ),
        const SizedBox(height: 14),
        if (!canEdit)
          Card(
            color: AppColors.lightOrange,
            child: const Padding(
              padding: EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.history_outlined, color: Color(0xFFE98500)),
                  SizedBox(width: 10),
                  Expanded(child: Text('当前考勤组已停用，仅可查看历史名单，不能新增、复制或批量加入人员。')),
                ],
              ),
            ),
          ),
        if (!canEdit) const SizedBox(height: 14),
        _RosterStats(counts: counts),
        const SizedBox(height: 14),
        _RosterActions(
          enabled: canEdit,
          onAdd: () => _showAddSheet(context, ref, activeIds),
          onBatch: () => _addDefaultEmployees(context, ref, selectedGroup),
          onCopy: () => _copyPreviousMonth(context, ref, selectedGroup),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('名单人员', style: Theme.of(context).textTheme.titleLarge),
            FilterChip(
              selected: showRemoved,
              onSelected: (value) =>
                  ref.read(monthlyRosterShowRemovedProvider.notifier).state =
                      value,
              avatar: const Icon(Icons.history_outlined, size: 17),
              label: const Text('显示已移除'),
              selectedColor: AppColors.lightOrange,
            ),
          ],
        ),
        const SizedBox(height: 10),
        entries.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _RosterError(
            onRetry: () => ref.invalidate(monthlyRosterEntriesProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _RosterEmpty(
                showRemoved: showRemoved,
                onAdd: canEdit
                    ? () => _showAddSheet(context, ref, activeIds)
                    : null,
              );
            }
            return Column(
              children: [
                for (final item in items) ...[
                  _RosterEmployeeCard(
                    item: item,
                    canRestore: canEdit,
                    onRemove: item.roster.isActive
                        ? () => _removeEmployee(context, ref, item)
                        : null,
                    onRestore: item.roster.isActive
                        ? null
                        : canEdit
                        ? () => _restoreEmployee(context, ref, item)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showAddSheet(
    BuildContext context,
    WidgetRef ref,
    Set<int> activeIds,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddRosterEmployeeSheet(activeIds: activeIds),
    );
  }

  Future<void> _addDefaultEmployees(
    BuildContext context,
    WidgetRef ref,
    AttendanceGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('按默认组加入？'),
        content: Text('将把当前仍符合月份规则、默认考勤组为“${group.name}”的人员加入名单。已有人员不会重复添加。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认加入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final count = await ref
          .read(monthlyRosterRepositoryProvider)
          .addDefaultGroupEmployees(
            yearMonth: AppDateUtils.yearMonth(
              ref.read(monthlyRosterMonthProvider),
            ),
            groupId: group.id,
          );
      if (context.mounted) {
        _showMessage(
          context,
          count == 0 ? '没有新增人员，当前名单已是最新。' : '已加入 $count 人。',
        );
      }
    } catch (error) {
      if (context.mounted) _showMessage(context, '批量加入失败：$error');
    }
  }

  Future<void> _copyPreviousMonth(
    BuildContext context,
    WidgetRef ref,
    AttendanceGroup group,
  ) async {
    final month = ref.read(monthlyRosterMonthProvider);
    final previous = DateTime(month.year, month.month - 1);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('复制上月名单？'),
        content: Text(
          '将把 ${AppDateUtils.yearMonth(previous)} 的有效名单加入本月，并保留本月已有的手动调整。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('复制'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final result = await ref
          .read(monthlyRosterRepositoryProvider)
          .copyFromPreviousMonth(
            yearMonth: AppDateUtils.yearMonth(month),
            groupId: group.id,
          );
      if (context.mounted) {
        _showMessage(
          context,
          result.count == 0
              ? '上月没有可复制的新人员。'
              : '已从 ${result.sourceYearMonth} 复制 ${result.count} 人。',
        );
      }
    } catch (error) {
      if (context.mounted) _showMessage(context, '复制失败：$error');
    }
  }

  Future<void> _removeEmployee(
    BuildContext context,
    WidgetRef ref,
    MonthlyRosterEntryView item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除本月名单？'),
        content: Text('只会移除 ${item.employee.name} 在当前月份的考勤范围，不会修改人员档案或默认考勤组。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(monthlyRosterRepositoryProvider)
          .removeEmployee(
            yearMonth: AppDateUtils.yearMonth(
              ref.read(monthlyRosterMonthProvider),
            ),
            groupId: ref.read(monthlyRosterGroupIdProvider)!,
            employeeId: item.employee.id,
          );
    } catch (error) {
      if (context.mounted) _showMessage(context, '移除失败：$error');
    }
  }

  Future<void> _restoreEmployee(
    BuildContext context,
    WidgetRef ref,
    MonthlyRosterEntryView item,
  ) async {
    try {
      await ref
          .read(monthlyRosterRepositoryProvider)
          .restoreEmployee(
            yearMonth: AppDateUtils.yearMonth(
              ref.read(monthlyRosterMonthProvider),
            ),
            groupId: ref.read(monthlyRosterGroupIdProvider)!,
            employeeId: item.employee.id,
          );
    } catch (error) {
      if (context.mounted) _showMessage(context, '恢复失败：$error');
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RosterHero extends StatelessWidget {
  const _RosterHero({required this.month, required this.group});

  final DateTime month;
  final AttendanceGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: LinearGradient(
          colors: group.isEnabled
              ? const [Color(0xFFE8F7F0), Color(0xFFE8F1FF)]
              : const [Color(0xFFF3F5F7), Color(0xFFECEFF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: group.isEnabled ? AppColors.primary : AppColors.helper,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('月度名单', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 5),
                Text(
                  '${month.year}年${month.month.toString().padLeft(2, '0')}月 · ${group.name}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _RosterStatusChip(
                      label: group.isEnabled ? '可维护' : '历史查看',
                      color: group.isEnabled
                          ? AppColors.primary
                          : AppColors.helper,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '独立于人员默认组',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterSelectors extends StatelessWidget {
  const _RosterSelectors({
    required this.month,
    required this.groups,
    required this.selectedGroup,
    required this.onMonthChanged,
    required this.onGroupChanged,
  });

  final DateTime month;
  final List<AttendanceGroup> groups;
  final AttendanceGroup selectedGroup;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<int?> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          children: [
            OutlinedButton.icon(
              key: const Key('monthly-roster-month-button'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: month,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2099),
                  helpText: '选择月份',
                );
                if (picked != null) {
                  onMonthChanged(DateTime(picked.year, picked.month));
                }
              },
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                '${month.year}年${month.month.toString().padLeft(2, '0')}月',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('monthly-roster-group-field'),
              initialValue: selectedGroup.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '考勤组',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              items: [
                for (final group in groups)
                  DropdownMenuItem(
                    value: group.id,
                    child: Text(
                      '${group.name}${group.isEnabled ? '' : '（已停用）'}',
                    ),
                  ),
              ],
              onChanged: onGroupChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterStats extends StatelessWidget {
  const _RosterStats({required this.counts});

  final AsyncValue<MonthlyRosterCounts> counts;

  @override
  Widget build(BuildContext context) {
    final value = counts.maybeWhen(
      data: (item) => item,
      orElse: () => const MonthlyRosterCounts(),
    );
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '本月有效',
            count: value.activeCount,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: '已移除',
            count: value.removedCount,
            color: AppColors.helper,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  '$count 人',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterActions extends StatelessWidget {
  const _RosterActions({
    required this.enabled,
    required this.onAdd,
    required this.onBatch,
    required this.onCopy,
  });

  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onBatch;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('名单维护', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('monthly-roster-add-button'),
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('添加人员'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('monthly-roster-batch-button'),
                    onPressed: enabled ? onBatch : null,
                    icon: const Icon(Icons.playlist_add_outlined),
                    label: const Text('按默认组加入'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('monthly-roster-copy-button'),
                    onPressed: enabled ? onCopy : null,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('复制上月'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterEmployeeCard extends StatelessWidget {
  const _RosterEmployeeCard({
    required this.item,
    this.canRestore = false,
    this.onRemove,
    this.onRestore,
  });

  final MonthlyRosterEntryView item;
  final bool canRestore;
  final VoidCallback? onRemove;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final employee = item.employee;
    final removed = !item.roster.isActive;
    final details = [
      employee.employeeNo,
      if (employee.position?.isNotEmpty ?? false) employee.position!,
      if (employee.employmentType?.isNotEmpty ?? false)
        employee.employmentType!,
      PersonnelOptions.statusLabel(employee.status),
    ].join(' · ');
    return Card(
      color: removed ? const Color(0xFFFBFCFD) : AppColors.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: removed ? AppColors.background : AppColors.lightBlue,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                removed ? Icons.person_off_outlined : Icons.person_outline,
                color: removed ? AppColors.helper : AppColors.techBlue,
              ),
            ),
            const SizedBox(width: 12),
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: removed ? AppColors.body : AppColors.ink,
                              ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      _RosterStatusChip(
                        label: removed ? '已移除' : '有效',
                        color: removed ? AppColors.helper : AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.roster.source == 'copied' ? '来源：上月复制' : '来源：手动维护',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: removed ? onRestore : onRemove,
              icon: Icon(
                removed ? Icons.restore_outlined : Icons.person_remove_outlined,
              ),
              tooltip: removed ? '恢复人员' : '移除人员',
              color: removed ? AppColors.techBlue : AppColors.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterStatusChip extends StatelessWidget {
  const _RosterStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RosterEmpty extends StatelessWidget {
  const _RosterEmpty({required this.showRemoved, this.onAdd});

  final bool showRemoved;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
        child: Column(
          children: [
            const Icon(
              Icons.event_available_outlined,
              color: AppColors.helper,
              size: 38,
            ),
            const SizedBox(height: 11),
            Text(
              showRemoved ? '本月还没有名单记录' : '本月暂无有效人员',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              showRemoved
                  ? '可以添加人员，或从上月复制名单。'
                  : '添加人员后，他们才会进入本月考勤范围。已移除人员可打开“显示已移除”查看。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('添加人员'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoAttendanceGroup extends StatelessWidget {
  const _NoAttendanceGroup({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.lightBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_outlined,
                color: AppColors.techBlue,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text('暂无考勤组', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '先建立一个启用中的考勤组，才能维护月度考勤名单。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('去管理考勤组'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterError extends StatelessWidget {
  const _RosterError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: 12),
            Text('月度名单暂时不可用', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '请重试；当前不会写入任何临时数据。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}

class _AddRosterEmployeeSheet extends ConsumerStatefulWidget {
  const _AddRosterEmployeeSheet({required this.activeIds});

  final Set<int> activeIds;

  @override
  ConsumerState<_AddRosterEmployeeSheet> createState() =>
      _AddRosterEmployeeSheetState();
}

class _AddRosterEmployeeSheetState
    extends ConsumerState<_AddRosterEmployeeSheet> {
  final _searchController = TextEditingController();
  String _search = '';
  int? _addingEmployeeId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(monthlyRosterCandidatesProvider);
    final month = AppDateUtils.yearMonth(ref.watch(monthlyRosterMonthProvider));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('添加本月人员', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(
                '$month · 仅显示入职日期不晚于本月末的人员。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: '搜索姓名、编号、岗位或用工类型',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: employees.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(child: Text('人员列表加载失败')),
                  data: (items) {
                    final query = _search.trim().toLowerCase();
                    final candidates = items.where((employee) {
                      if (widget.activeIds.contains(employee.id)) return false;
                      if (query.isEmpty) return true;
                      return [
                        employee.name,
                        employee.employeeNo,
                        employee.position,
                        employee.employmentType,
                      ].whereType<String>().any(
                        (value) => value.toLowerCase().contains(query),
                      );
                    }).toList();
                    if (candidates.isEmpty) {
                      return Center(
                        child: Text(
                          items.isEmpty ? '暂无符合月份规则的人员。' : '没有匹配的未加入人员。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: candidates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final employee = candidates[index];
                        final isAdding = _addingEmployeeId == employee.id;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.lightBlue,
                              foregroundColor: AppColors.techBlue,
                              child: Text(employee.name.characters.first),
                            ),
                            title: Text(employee.name),
                            subtitle: Text(
                              '${employee.employeeNo} · ${employee.position?.isNotEmpty == true ? employee.position : '岗位未填写'} · ${PersonnelOptions.statusLabel(employee.status)}',
                            ),
                            trailing: isAdding
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.primary,
                                  ),
                            onTap: isAdding
                                ? null
                                : () => _addEmployee(employee),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addEmployee(Employee employee) async {
    setState(() => _addingEmployeeId = employee.id);
    try {
      await ref
          .read(monthlyRosterRepositoryProvider)
          .addEmployee(
            yearMonth: AppDateUtils.yearMonth(
              ref.read(monthlyRosterMonthProvider),
            ),
            groupId: ref.read(monthlyRosterGroupIdProvider)!,
            employeeId: employee.id,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _addingEmployeeId = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('添加失败：$error')));
      }
    }
  }
}
