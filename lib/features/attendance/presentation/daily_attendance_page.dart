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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '自动保存',
                style: TextStyle(color: AppColors.body, fontSize: 14),
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
        const SizedBox(height: 16),

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
                _DailyAttendanceOverview(items: items),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '人员台账',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const _DailyAttendanceTableHeader(),
                        for (final entry in items) ...[
                          _DailyAttendanceEmployeeCard(
                            key: ValueKey(
                              '${entry.employee.id}-${entry.attendanceDate.toIso8601String()}',
                            ),
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
                          const Divider(),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final status in const [
                              AttendanceHalfStatus.present,
                              AttendanceHalfStatus.leave,
                              AttendanceHalfStatus.rest,
                              AttendanceHalfStatus.unregistered,
                              AttendanceHalfStatus.absent,
                              AttendanceHalfStatus.stopped,
                            ])
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _DailyAttendanceEmployeeCardState._legendColor(
                                            status,
                                          ).withValues(alpha: .11),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _DailyAttendanceEmployeeCardState._statusIcon(
                                            status,
                                          ),
                                          color:
                                              _DailyAttendanceEmployeeCardState._legendColor(
                                                status,
                                              ),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _DailyAttendanceEmployeeCardState._shortStatus(
                                            status,
                                          ),
                                          style: TextStyle(
                                            color:
                                                _DailyAttendanceEmployeeCardState._legendColor(
                                                  status,
                                                ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DailyAttendanceOptions.statusLabel(status),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.body,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (sheetContext) => SafeArea(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '批量操作',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                _DailyAttendanceActions(
                                  onAction: (action) {
                                    Navigator.pop(sheetContext);
                                    _runAction(context, ref, action);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('批量操作'),
                  ),
                ),
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
  ) => ref.read(dailyAttendanceRepositoryProvider).save(draft);

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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final dateButton = OutlinedButton.icon(
        key: const Key('daily-attendance-date-button'),
        icon: const Icon(Icons.calendar_month_outlined, color: AppColors.body),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.divider),
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2099),
            helpText: '选择考勤日期',
          );
          if (picked != null) onDateChanged(AppDateUtils.dateOnly(picked));
        },
        label: Row(
          children: [
            Expanded(
              child: Text(
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${_weekdayLabel(date.weekday)}',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: AppColors.body),
          ],
        ),
      );
      final groupButton = PopupMenuButton<int>(
        key: Key('daily-attendance-group-${selectedGroup.id}'),
        tooltip: '选择考勤组',
        initialValue: selectedGroup.id,
        onSelected: onGroupChanged,
        itemBuilder: (context) => [
          for (final group in groups)
            CheckedPopupMenuItem(
              value: group.id,
              checked: group.id == selectedGroup.id,
              child: Text('${group.name}（${memberCounts[group.id] ?? 0}人）'),
            ),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups, color: AppColors.body),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedGroup.name,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.expand_more, color: AppColors.body, size: 18),
            ],
          ),
        ),
      );
      if (MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
          children: [dateButton, const SizedBox(height: 8), groupButton],
        );
      }
      return Row(
        children: [
          Expanded(flex: 6, child: dateButton),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: groupButton),
        ],
      );
    },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(14) > 17
            ? 2
            : 4;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 6) / columns,
                child: Material(
                  color: actions[index].$3.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: Key(
                      'daily-attendance-action-${actions[index].$1.name}',
                    ),
                    onTap: () => onAction(actions[index].$1),
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 78),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
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
                              DailyAttendanceOptions.actionLabel(
                                actions[index].$1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
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
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DailyAttendanceOverview extends StatelessWidget {
  const _DailyAttendanceOverview({required this.items});
  final List<DailyAttendanceEntryView> items;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('考勤概况', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth < 290 ||
                      MediaQuery.textScalerOf(context).scale(14) > 17
                  ? 2
                  : 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in [
                    (
                      '名单人数',
                      '${items.length}人',
                      Icons.groups_outlined,
                      AppColors.success,
                    ),
                    (
                      '上午已登记',
                      '${items.where((item) => item.morningStatus != AttendanceHalfStatus.unregistered).length}/${items.length}',
                      Icons.event_available_outlined,
                      AppColors.techBlue,
                    ),
                    (
                      '下午已登记',
                      '${items.where((item) => item.afternoonStatus != AttendanceHalfStatus.unregistered).length}/${items.length}',
                      Icons.event_available_outlined,
                      const Color(0xFFE98500),
                    ),
                  ])
                    SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 8) / columns,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: metric.$4.withValues(alpha: .1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                metric.$3,
                                color: metric.$4,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    metric.$1,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.body,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    metric.$2,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _DailyAttendanceTableHeader extends StatelessWidget {
  const _DailyAttendanceTableHeader();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.lightBlue,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      children: [
        SizedBox(width: 128, child: Text('姓名')),
        Expanded(child: Center(child: Text('上午'))),
        Expanded(child: Center(child: Text('下午'))),
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
  bool _saving = false;
  String? _saveFeedback;
  bool _saveFailed = false;

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
    final compact =
        MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(14) > 17;
    final name = Tooltip(
      message: employee.employeeNo,
      child: Text(
        employee.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
    final statuses = Row(
      children: [
        Expanded(
          child: _buildStatusField(
            context,
            widget.entry.morningStatus,
            'morning',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusField(
            context,
            widget.entry.afternoonStatus,
            'afternoon',
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            name,
            const SizedBox(height: 8),
            statuses,
            _metadata(context),
          ] else
            Row(
              children: [
                SizedBox(width: 128, child: _metadata(context, name: name)),
                Expanded(child: statuses),
              ],
            ),
          if (_saveFeedback != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _saveFeedback!,
                key: Key('daily-attendance-save-${employee.id}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _saveFailed ? AppColors.danger : AppColors.success,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metadata(BuildContext context, {Widget? name}) {
    final employee = widget.entry.employee;
    final overtime =
        widget.overtimeUnavailable ??
        (widget.overtimeMinutes == 0
            ? '0小时'
            : _formatDuration(widget.overtimeMinutes));
    return Row(
      children: [
        Expanded(
          child: TextButton(
            key: Key('daily-attendance-overtime-${employee.id}'),
            onPressed: () => context.push('/attendance/overtime'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.body,
              minimumSize: const Size(48, 48),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name != null) ...[name, const SizedBox(height: 4)],
                Text(
                  '加班 $overtime',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        TextButton(
          key: Key('daily-attendance-remark-${employee.id}'),
          onPressed: widget.entry.isEditable && !_saving ? _editRemark : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.body,
            minimumSize: const Size(48, 48),
          ),
          child: Tooltip(
            message: _remarkController.text.isEmpty
                ? '编辑备注'
                : _remarkController.text,
            child: const Text('备注 ›', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusField(
    BuildContext context,
    AttendanceHalfStatus status,
    String part,
  ) {
    final color = _statusColor(status);
    final half = part == 'morning' ? '上午' : '下午';
    final label = DailyAttendanceOptions.statusLabel(status);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_statusIcon(status), color: color, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _shortStatus(status),
            softWrap: false,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    final decoration = BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(8),
    );
    if (!widget.entry.isEditable) {
      return Semantics(
        label: '${widget.entry.employee.name} $half $label，不可编辑',
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(8),
          decoration: decoration,
          alignment: Alignment.center,
          child: FittedBox(fit: BoxFit.scaleDown, child: content),
        ),
      );
    }
    return PopupMenuButton<AttendanceHalfStatus>(
      key: Key('daily-attendance-$part-${widget.entry.employee.id}'),
      tooltip: '${widget.entry.employee.name} $half考勤：$label',
      enabled: !_saving,
      initialValue: status,
      position: PopupMenuPosition.under,
      onSelected: (selected) {
        if (selected == status) return;
        _save(
          morning: part == 'morning' ? selected : null,
          afternoon: part == 'afternoon' ? selected : null,
        );
      },
      itemBuilder: (context) => [
        for (final option in DailyAttendanceOptions.editableStatuses)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(_statusIcon(option), color: _statusColor(option)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(DailyAttendanceOptions.statusLabel(option)),
                ),
                if (option == status)
                  const Icon(Icons.check, color: AppColors.primary),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: decoration,
        alignment: Alignment.center,
        child: FittedBox(fit: BoxFit.scaleDown, child: content),
      ),
    );
  }

  static String _shortStatus(AttendanceHalfStatus status) => switch (status) {
    AttendanceHalfStatus.present => '全',
    AttendanceHalfStatus.leave => '半',
    AttendanceHalfStatus.absent => '缺',
    AttendanceHalfStatus.rest => '休',
    AttendanceHalfStatus.stopped => '停',
    AttendanceHalfStatus.unregistered => '未',
    _ => DailyAttendanceOptions.statusLabel(status),
  };

  static IconData _statusIcon(AttendanceHalfStatus status) => switch (status) {
    AttendanceHalfStatus.present => Icons.check_circle,
    AttendanceHalfStatus.leave => Icons.pie_chart,
    AttendanceHalfStatus.absent => Icons.error,
    AttendanceHalfStatus.rest => Icons.bed,
    AttendanceHalfStatus.stopped => Icons.block,
    _ => Icons.remove,
  };

  Future<void> _editRemark() async {
    final controller = TextEditingController(text: _remarkController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('考勤备注', textAlign: TextAlign.center),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 100,
          decoration: const InputDecoration(hintText: '输入备注'),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: const Text('保存备注'),
                ),
              ),
            ],
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
  }) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
      _saveFeedback = '保存中…';
    });
    try {
      await widget.onSave(
        DailyAttendanceDraft(
          employeeId: widget.entry.employee.id,
          attendanceDate: widget.entry.attendanceDate,
          morningStatus: morning ?? widget.entry.morningStatus,
          afternoonStatus: afternoon ?? widget.entry.afternoonStatus,
          remark: _remarkController.text,
        ),
      );
      if (mounted) setState(() => _saveFeedback = '已自动保存');
    } catch (error) {
      if (mounted) {
        setState(() {
          _saveFailed = true;
          _saveFeedback = '保存失败，请重新选择或编辑后重试';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '$remainder分钟';
    return remainder == 0 ? '$hours小时' : '$hours小时$remainder分';
  }

  Color _statusColor(AttendanceHalfStatus status) => _legendColor(status);

  static Color _legendColor(AttendanceHalfStatus status) => switch (status) {
    AttendanceHalfStatus.present => AppColors.success,
    AttendanceHalfStatus.leave => AppColors.warning,
    AttendanceHalfStatus.absent => AppColors.body,
    AttendanceHalfStatus.rest => AppColors.purple,
    AttendanceHalfStatus.stopped => const Color(0xFFE98500),
    AttendanceHalfStatus.unregistered => AppColors.helper,
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
