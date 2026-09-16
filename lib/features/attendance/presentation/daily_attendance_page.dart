import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../personnel/domain/personnel_options.dart';
import '../application/daily_attendance_providers.dart';
import '../domain/daily_attendance_options.dart';

class DailyAttendancePage extends ConsumerWidget {
  const DailyAttendancePage({super.key, this.fromHomeShortcut = false});

  final bool fromHomeShortcut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(dailyAttendanceGroupsProvider);
    return PopScope(
      canPop: !fromHomeShortcut,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && fromHomeShortcut) {
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: fromHomeShortcut ? '返回首页' : '返回',
            onPressed: () =>
                fromHomeShortcut ? context.go('/home') : context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('每日考勤'),
          actions: [
            IconButton(
              onPressed: () => context.push('/attendance/monthly-roster'),
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: '月度考勤名单',
            ),
          ],
        ),
        body: groups.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _DailyAttendanceError(
            onRetry: () => ref.invalidate(dailyAttendanceGroupsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _NoDailyAttendanceGroup(
                onManage: () => context.push('/attendance/groups'),
              );
            }
            return _DailyAttendanceContent(groups: items);
          },
        ),
      ),
    );
  }
}

class _DailyAttendanceContent extends ConsumerWidget {
  const _DailyAttendanceContent({required this.groups});

  final List<AttendanceGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(dailyAttendanceDateProvider);
    final selectedId = ref.watch(dailyAttendanceGroupIdProvider);
    final selectedGroup = groups.firstWhere(
      (group) => group.id == selectedId,
      orElse: () => groups.first,
    );
    if (selectedId != selectedGroup.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(dailyAttendanceGroupIdProvider) != selectedGroup.id) {
          ref.read(dailyAttendanceGroupIdProvider.notifier).state =
              selectedGroup.id;
        }
      });
    }

    final entries = ref.watch(dailyAttendanceEntriesProvider);
    final registeredCount = entries.maybeWhen(
      data: (items) => items.where((item) => item.isRegistered).length,
      orElse: () => 0,
    );
    final lockedCount = entries.maybeWhen(
      data: (items) => items.where((item) => !item.isEditable).length,
      orElse: () => 0,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _DailyAttendanceHero(date: date, group: selectedGroup),
        const SizedBox(height: 14),
        _DailyAttendanceSelectors(
          date: date,
          groups: groups,
          selectedGroup: selectedGroup,
          onDateChanged: (value) =>
              ref.read(dailyAttendanceDateProvider.notifier).state = value,
          onGroupChanged: (value) {
            if (value != null) {
              ref.read(dailyAttendanceGroupIdProvider.notifier).state = value;
            }
          },
        ),
        const SizedBox(height: 14),
        _DailyAttendanceStats(
          total: entries.maybeWhen(
            data: (items) => items.length,
            orElse: () => 0,
          ),
          registered: registeredCount,
          locked: lockedCount,
        ),
        const SizedBox(height: 14),
        _DailyAttendanceActions(
          onAction: (action) => _runAction(context, ref, action),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('考勤人员', style: Theme.of(context).textTheme.titleLarge),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_done_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '本地已保存',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        entries.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _DailyAttendanceError(
            onRetry: () => ref.invalidate(dailyAttendanceEntriesProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const _DailyAttendanceEmpty();
            }
            return Column(
              children: [
                for (final entry in items) ...[
                  _DailyAttendanceEmployeeCard(
                    key: ValueKey(entry.employee.id),
                    entry: entry,
                    onSave: (draft) => _saveEntry(context, ref, draft),
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

  Future<void> _saveEntry(
    BuildContext context,
    WidgetRef ref,
    DailyAttendanceDraft draft,
  ) async {
    try {
      await ref.read(dailyAttendanceRepositoryProvider).save(draft);
    } catch (error) {
      if (context.mounted) _showMessage(context, '保存失败：$error');
    }
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    DailyAttendanceAction action,
  ) async {
    final groupId = ref.read(dailyAttendanceGroupIdProvider);
    if (groupId == null) return;
    try {
      final count = await ref
          .read(dailyAttendanceRepositoryProvider)
          .applyAction(
            attendanceDate: ref.read(dailyAttendanceDateProvider),
            groupId: groupId,
            action: action,
          );
      if (context.mounted) {
        _showMessage(
          context,
          count == 0
              ? '${DailyAttendanceOptions.actionLabel(action)}：没有可更新的人员。'
              : '${DailyAttendanceOptions.actionLabel(action)}：已更新 $count 人。',
        );
      }
    } catch (error) {
      if (context.mounted) _showMessage(context, '批量操作失败：$error');
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DailyAttendanceHero extends StatelessWidget {
  const _DailyAttendanceHero({required this.date, required this.group});

  final DateTime date;
  final AttendanceGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F7F0), Color(0xFFE8F1FF)],
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
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('每日登记', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 5),
                Text(
                  '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日 · ${group.name}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '上午、下午分别登记，修改后立即保存。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyAttendanceSelectors extends StatelessWidget {
  const _DailyAttendanceSelectors({
    required this.date,
    required this.groups,
    required this.selectedGroup,
    required this.onDateChanged,
    required this.onGroupChanged,
  });

  final DateTime date;
  final List<AttendanceGroup> groups;
  final AttendanceGroup selectedGroup;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int?> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('daily-attendance-previous-day'),
                  onPressed: () => onDateChanged(
                    AppDateUtils.dateOnly(
                      date.subtract(const Duration(days: 1)),
                    ),
                  ),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: '前一天',
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('daily-attendance-date-button'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2099),
                        helpText: '选择考勤日期',
                      );
                      if (picked != null) {
                        onDateChanged(AppDateUtils.dateOnly(picked));
                      }
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('daily-attendance-next-day'),
                  onPressed: () => onDateChanged(
                    AppDateUtils.dateOnly(date.add(const Duration(days: 1))),
                  ),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: '后一天',
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('daily-attendance-today-button'),
                onPressed: () =>
                    onDateChanged(AppDateUtils.dateOnly(DateTime.now())),
                child: const Text('今天'),
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              key: const Key('daily-attendance-group-field'),
              initialValue: selectedGroup.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '考勤组',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              items: [
                for (final group in groups)
                  DropdownMenuItem(value: group.id, child: Text(group.name)),
              ],
              onChanged: onGroupChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyAttendanceStats extends StatelessWidget {
  const _DailyAttendanceStats({
    required this.total,
    required this.registered,
    required this.locked,
  });

  final int total;
  final int registered;
  final int locked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DailyStatCard(
            label: '名单',
            value: total,
            color: AppColors.techBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DailyStatCard(
            label: '已登记',
            value: registered,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DailyStatCard(
            label: '锁定',
            value: locked,
            color: AppColors.helper,
          ),
        ),
      ],
    );
  }
}

class _DailyStatCard extends StatelessWidget {
  const _DailyStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              '$value 人',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyAttendanceActions extends StatelessWidget {
  const _DailyAttendanceActions({required this.onAction});

  final ValueChanged<DailyAttendanceAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('快捷操作', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionButton(
                  key: const Key('daily-attendance-all-present'),
                  action: DailyAttendanceAction.allPresent,
                  onPressed: onAction,
                ),
                _ActionButton(
                  key: const Key('daily-attendance-copy-previous'),
                  action: DailyAttendanceAction.copyPrevious,
                  onPressed: onAction,
                ),
                _ActionButton(
                  key: const Key('daily-attendance-rest'),
                  action: DailyAttendanceAction.rest,
                  onPressed: onAction,
                ),
                _ActionButton(
                  key: const Key('daily-attendance-stopped'),
                  action: DailyAttendanceAction.stopped,
                  onPressed: onAction,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.onPressed,
    super.key,
  });

  final DailyAttendanceAction action;
  final ValueChanged<DailyAttendanceAction> onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onPressed(action),
      icon: Icon(switch (action) {
        DailyAttendanceAction.allPresent => Icons.done_all,
        DailyAttendanceAction.copyPrevious => Icons.copy_outlined,
        DailyAttendanceAction.rest => Icons.weekend_outlined,
        DailyAttendanceAction.stopped => Icons.pause_circle_outline,
      }, size: 18),
      label: Text(DailyAttendanceOptions.actionLabel(action)),
    );
  }
}

class _DailyAttendanceEmployeeCard extends StatefulWidget {
  const _DailyAttendanceEmployeeCard({
    required this.entry,
    required this.onSave,
    super.key,
  });

  final DailyAttendanceEntryView entry;
  final Future<void> Function(DailyAttendanceDraft draft) onSave;

  @override
  State<_DailyAttendanceEmployeeCard> createState() =>
      _DailyAttendanceEmployeeCardState();
}

class _DailyAttendanceEmployeeCardState
    extends State<_DailyAttendanceEmployeeCard> {
  late final TextEditingController _remarkController;
  late final FocusNode _remarkFocusNode;

  @override
  void initState() {
    super.initState();
    _remarkController = TextEditingController(text: widget.entry.remark ?? '');
    _remarkFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _DailyAttendanceEmployeeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.remark != widget.entry.remark &&
        !_remarkFocusNode.hasFocus) {
      _remarkController.text = widget.entry.remark ?? '';
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _remarkFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.entry.employee;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.lightBlue,
                  foregroundColor: AppColors.techBlue,
                  child: Text(employee.name.characters.first),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${employee.employeeNo} · ${employee.position?.isNotEmpty == true ? employee.position : '岗位未填写'} · ${PersonnelOptions.statusLabel(employee.status)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!widget.entry.isEditable)
                  Icon(Icons.lock_outline, color: AppColors.helper, size: 20),
              ],
            ),
            if (!widget.entry.isEditable) ...[
              const SizedBox(height: 8),
              Text(
                widget.entry.lockReason ?? '当前日期不可登记',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.helper),
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _buildStatusField(
                    context,
                    '上午',
                    widget.entry.morningStatus,
                    'morning',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatusField(
                    context,
                    '下午',
                    widget.entry.afternoonStatus,
                    'afternoon',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.more_time_outlined,
                  size: 19,
                  color: AppColors.helper,
                ),
                const SizedBox(width: 7),
                Text('加班时长', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 10),
                Text('上午、下午独立登记', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: Key('daily-attendance-remark-${employee.id}'),
              controller: _remarkController,
              focusNode: _remarkFocusNode,
              enabled: widget.entry.isEditable,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveCurrent(),
              onTapOutside: (_) => _saveCurrent(),
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusField(
    BuildContext context,
    String label,
    AttendanceHalfStatus status,
    String part,
  ) {
    if (!widget.entry.isEditable) {
      return Container(
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              DailyAttendanceOptions.statusLabel(status),
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.helper),
            ),
          ],
        ),
      );
    }
    final key = Key('daily-attendance-$part-${widget.entry.employee.id}');
    return DropdownButtonFormField<AttendanceHalfStatus>(
      key: key,
      initialValue: status,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
      items: [
        for (final option in DailyAttendanceOptions.editableStatuses)
          DropdownMenuItem(
            value: option,
            child: Text(DailyAttendanceOptions.statusLabel(option)),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        if (part == 'morning') {
          _save(morning: value);
        } else {
          _save(afternoon: value);
        }
      },
    );
  }

  Future<void> _save({
    AttendanceHalfStatus? morning,
    AttendanceHalfStatus? afternoon,
  }) {
    return widget.onSave(
      DailyAttendanceDraft(
        employeeId: widget.entry.employee.id,
        attendanceDate: widget.entry.attendanceDate,
        morningStatus: morning ?? widget.entry.morningStatus,
        afternoonStatus: afternoon ?? widget.entry.afternoonStatus,
        remark: _remarkController.text,
      ),
    );
  }

  Future<void> _saveCurrent() => _save();
}

class _DailyAttendanceEmpty extends StatelessWidget {
  const _DailyAttendanceEmpty();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
        child: Column(
          children: [
            const Icon(
              Icons.event_busy_outlined,
              color: AppColors.helper,
              size: 40,
            ),
            const SizedBox(height: 11),
            Text('本月暂无考勤人员', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '请先在月度考勤名单中加入人员，他们才会出现在每日登记列表。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDailyAttendanceGroup extends StatelessWidget {
  const _NoDailyAttendanceGroup({required this.onManage});

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
            Text('暂无启用中的考勤组', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '先建立并启用一个考勤组，再维护月度名单和每日考勤。',
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

class _DailyAttendanceError extends StatelessWidget {
  const _DailyAttendanceError({required this.onRetry});

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
            Text('每日考勤暂时不可用', style: Theme.of(context).textTheme.titleLarge),
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
