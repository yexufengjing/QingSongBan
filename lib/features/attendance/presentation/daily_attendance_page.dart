import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../overtime/application/overtime_providers.dart';
import '../../overtime/domain/overtime_options.dart';
import '../application/attendance_group_providers.dart';
import '../domain/attendance_group_options.dart';
import '../application/daily_attendance_providers.dart';
import '../domain/daily_attendance_options.dart';

class DailyAttendancePage extends ConsumerWidget {
  const DailyAttendancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(dailyAttendanceGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('每日考勤'),
        actions: [
          const Chip(
            avatar: Icon(
              Icons.check_circle,
              color: AppColors.primary,
              size: 16,
            ),
            label: Text('自动保存'),
            visualDensity: VisualDensity.compact,
            side: BorderSide.none,
            backgroundColor: AppColors.lightGreen,
          ),
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
    final overtimeState = ref.watch(
      overtimeRecordsForMonthProvider(DateTime(date.year, date.month)),
    );
    final overtimeRecords =
        overtimeState.valueOrNull ?? const <OvertimeRecordView>[];
    final overtimeUnavailable = overtimeState.when(
      loading: () => '加载中',
      error: (_, _) => '暂不可用',
      data: (_) => null,
    );
    final groupSummaries =
        ref.watch(attendanceGroupSummariesProvider).valueOrNull ??
        const <AttendanceGroupSummary>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        _DailyAttendanceSelectors(
          date: date,
          groups: groups,
          selectedGroup: selectedGroup,
          memberCounts: {
            for (final summary in groupSummaries)
              summary.group.id: summary.memberCount,
          },
          onDateChanged: (value) =>
              ref.read(dailyAttendanceDateProvider.notifier).state = value,
          onGroupChanged: (value) {
            if (value != null) {
              ref.read(dailyAttendanceGroupIdProvider.notifier).state = value;
            }
          },
        ),
        const SizedBox(height: 8),
        _DailyAttendanceActions(
          onAction: (action) => _runAction(context, ref, action),
        ),
        const SizedBox(height: 8),
        const _DailyAttendanceTableHeader(),
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
                    overtimeUnavailable: overtimeUnavailable,
                    overtimeMinutes: overtimeRecords
                        .where(
                          (item) =>
                              item.employee.id == entry.employee.id &&
                              AppDateUtils.dateOnly(
                                    item.overtime.overtimeDate,
                                  ) ==
                                  AppDateUtils.dateOnly(date),
                        )
                        .fold<int>(
                          0,
                          (total, item) =>
                              total +
                              item.overtime.endTime
                                  .difference(item.overtime.startTime)
                                  .inMinutes,
                        ),
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

class _DailyAttendanceSelectors extends StatelessWidget {
  const _DailyAttendanceSelectors({
    required this.date,
    required this.groups,
    required this.selectedGroup,
    required this.memberCounts,
    required this.onDateChanged,
    required this.onGroupChanged,
  });

  final DateTime date;
  final List<AttendanceGroup> groups;
  final AttendanceGroup selectedGroup;
  final Map<int, int> memberCounts;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int?> onGroupChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.techBlue,
                size: 18,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextButton(
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${_weekdayLabel(date.weekday)}',
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('daily-attendance-previous-day'),
                onPressed: () => onDateChanged(
                  AppDateUtils.dateOnly(date.subtract(const Duration(days: 1))),
                ),
                icon: const Icon(Icons.chevron_left),
                tooltip: '前一天',
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
              ),
              TextButton(
                key: const Key('daily-attendance-today-button'),
                onPressed: () =>
                    onDateChanged(AppDateUtils.dateOnly(DateTime.now())),
                style: TextButton.styleFrom(
                  minimumSize: const Size(36, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('今天'),
              ),
              IconButton(
                key: const Key('daily-attendance-next-day'),
                onPressed: () => onDateChanged(
                  AppDateUtils.dateOnly(date.add(const Duration(days: 1))),
                ),
                icon: const Icon(Icons.chevron_right),
                tooltip: '后一天',
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: groups.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            final count = memberCounts[group.id];
            final selected = group.id == selectedGroup.id;
            return ChoiceChip(
              key: Key('daily-attendance-group-${group.id}'),
              label: Text(
                count == null ? group.name : '${group.name}（$count人）',
              ),
              selected: selected,
              onSelected: (_) => onGroupChanged(group.id),
              showCheckmark: false,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.lightBlue,
              side: BorderSide.none,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          },
        ),
      ),
    ],
  );

  static String _weekdayLabel(int weekday) => switch (weekday) {
    DateTime.monday => '周一',
    DateTime.tuesday => '周二',
    DateTime.wednesday => '周三',
    DateTime.thursday => '周四',
    DateTime.friday => '周五',
    DateTime.saturday => '周六',
    _ => '周日',
  };
}

class _DailyAttendanceActions extends StatelessWidget {
  const _DailyAttendanceActions({required this.onAction});

  final ValueChanged<DailyAttendanceAction> onAction;

  @override
  Widget build(BuildContext context) {
    const actions = [
      (DailyAttendanceAction.allPresent, Icons.done_all, AppColors.primary),
      (
        DailyAttendanceAction.copyPrevious,
        Icons.copy_outlined,
        AppColors.techBlue,
      ),
      (DailyAttendanceAction.rest, Icons.weekend_outlined, Color(0xFFE98500)),
      (
        DailyAttendanceAction.stopped,
        Icons.pause_circle_outline,
        AppColors.danger,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: Material(
              color: actions[index].$3.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: Key('daily-attendance-action-${actions[index].$1.name}'),
                onTap: () => onAction(actions[index].$1),
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 78,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        actions[index].$2,
                        color: actions[index].$3,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DailyAttendanceOptions.actionLabel(actions[index].$1),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DailyAttendanceTableHeader extends StatelessWidget {
  const _DailyAttendanceTableHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
    child: Row(
      children: [
        const SizedBox(width: 86, child: Text('姓名')),
        const Expanded(child: Center(child: Text('上午'))),
        const Expanded(child: Center(child: Text('下午'))),
        const SizedBox(width: 64, child: Center(child: Text('加班时长'))),
        const SizedBox(width: 38, child: Center(child: Text('备注'))),
      ],
    ),
  );
}

class _DailyAttendanceEmployeeCard extends StatefulWidget {
  const _DailyAttendanceEmployeeCard({
    required this.entry,
    required this.overtimeMinutes,
    required this.overtimeUnavailable,
    required this.onSave,
    super.key,
  });

  final DailyAttendanceEntryView entry;
  final int overtimeMinutes;
  final String? overtimeUnavailable;
  final Future<void> Function(DailyAttendanceDraft draft) onSave;

  @override
  State<_DailyAttendanceEmployeeCard> createState() =>
      _DailyAttendanceEmployeeCardState();
}

class _DailyAttendanceEmployeeCardState
    extends State<_DailyAttendanceEmployeeCard> {
  late final TextEditingController _remarkController;

  @override
  void initState() {
    super.initState();
    _remarkController = TextEditingController(text: widget.entry.remark ?? '');
  }

  @override
  void didUpdateWidget(covariant _DailyAttendanceEmployeeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.remark != widget.entry.remark) {
      _remarkController.text = widget.entry.remark ?? '';
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.entry.employee;
    final overtime =
        widget.overtimeUnavailable ??
        (widget.overtimeMinutes == 0
            ? '无'
            : _formatDuration(widget.overtimeMinutes));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '工号 ${employee.employeeNo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildStatusField(
                context,
                widget.entry.morningStatus,
                'morning',
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _buildStatusField(
                context,
                widget.entry.afternoonStatus,
                'afternoon',
              ),
            ),
            SizedBox(
              width: 59,
              child: TextButton(
                key: Key('daily-attendance-overtime-${employee.id}'),
                onPressed: () => context.push('/attendance/overtime'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                ),
                child: Text(
                  overtime,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.ink),
                ),
              ),
            ),
            IconButton(
              key: Key('daily-attendance-remark-${employee.id}'),
              tooltip: _remarkController.text.isEmpty
                  ? '添加备注'
                  : '备注：${_remarkController.text}',
              onPressed: widget.entry.isEditable ? _editRemark : null,
              icon: Icon(
                _remarkController.text.isEmpty
                    ? Icons.notes_outlined
                    : Icons.sticky_note_2_outlined,
                color: _remarkController.text.isEmpty
                    ? AppColors.helper
                    : AppColors.techBlue,
                size: 20,
              ),
            ),
            if (!widget.entry.isEditable)
              const Icon(Icons.lock_outline, color: AppColors.helper, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusField(
    BuildContext context,
    AttendanceHalfStatus status,
    String part,
  ) {
    final color = _statusColor(status);
    final key = Key('daily-attendance-$part-${widget.entry.employee.id}');
    if (!widget.entry.isEditable) {
      return Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          DailyAttendanceOptions.statusLabel(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      );
    }
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AttendanceHalfStatus>(
          key: key,
          value: status,
          isExpanded: true,
          icon: Icon(Icons.expand_more, size: 16, color: color),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
          items: [
            for (final option in DailyAttendanceOptions.editableStatuses)
              DropdownMenuItem(
                value: option,
                child: Text(
                  DailyAttendanceOptions.statusLabel(option),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
        ),
      ),
    );
  }

  Future<void> _editRemark() async {
    final controller = TextEditingController(text: _remarkController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('考勤备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 100,
          decoration: const InputDecoration(hintText: '输入备注'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存备注'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    _remarkController.text = result;
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _save({
    AttendanceHalfStatus? morning,
    AttendanceHalfStatus? afternoon,
  }) => widget.onSave(
    DailyAttendanceDraft(
      employeeId: widget.entry.employee.id,
      attendanceDate: widget.entry.attendanceDate,
      morningStatus: morning ?? widget.entry.morningStatus,
      afternoonStatus: afternoon ?? widget.entry.afternoonStatus,
      remark: _remarkController.text,
    ),
  );

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '$remainder分钟';
    return remainder == 0 ? '$hours小时' : '$hours小时$remainder分';
  }

  Color _statusColor(AttendanceHalfStatus status) => switch (status) {
    AttendanceHalfStatus.present => AppColors.primary,
    AttendanceHalfStatus.leave ||
    AttendanceHalfStatus.absent => AppColors.danger,
    AttendanceHalfStatus.rest => AppColors.body,
    AttendanceHalfStatus.stopped => const Color(0xFFE98500),
    AttendanceHalfStatus.unregistered => AppColors.techBlue,
    AttendanceHalfStatus.notEmployed ||
    AttendanceHalfStatus.terminated => AppColors.helper,
  };
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
