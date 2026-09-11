import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/attendance_group_providers.dart';
import '../domain/attendance_group_options.dart';
import 'attendance_group_widgets.dart';

class AttendanceGroupListPage extends ConsumerWidget {
  const AttendanceGroupListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(attendanceGroupSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('考勤组'),
        actions: [
          IconButton(
            onPressed: () => context.push('/attendance/groups/new'),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新增考勤组',
          ),
        ],
      ),
      body: SafeArea(
        child: groups.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AttendanceGroupErrorState(
            onRetry: () => ref.invalidate(attendanceGroupSummariesProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return AttendanceGroupEmptyState(
                onCreate: () => context.push('/attendance/groups/new'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _GroupListIntro(count: items.length);
                }
                final summary = items[index - 1];
                return _AttendanceGroupCard(summary: summary);
              },
            );
          },
        ),
      ),
    );
  }
}

class _GroupListIntro extends StatelessWidget {
  const _GroupListIntro({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightGreen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
        child: Row(
          children: [
            const Icon(Icons.tune_outlined, color: AppColors.primary),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                '$count 个考勤组 · 为每位人员指定一个默认组',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceGroupCard extends ConsumerWidget {
  const _AttendanceGroupCard({required this.summary});

  final AttendanceGroupSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = summary.group;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/attendance/groups/${group.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 16, 10, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: group.isEnabled
                      ? AppColors.lightGreen
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.groups_outlined,
                  color: group.isEnabled ? AppColors.primary : AppColors.helper,
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
                            group.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AttendanceGroupStatusBadge(enabled: group.isEnabled),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${summary.memberCount} 名成员 · 手动分组 · 排序 ${group.sortOrder}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: group.isEnabled,
                    onChanged: (value) => _toggle(context, ref, group, value),
                  ),
                  IconButton(
                    onPressed: () =>
                        context.push('/attendance/groups/${group.id}/edit'),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: '编辑考勤组',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    AttendanceGroup group,
    bool enabled,
  ) async {
    try {
      await ref
          .read(attendanceGroupRepositoryProvider)
          .setEnabled(group.id, enabled);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('更新失败：$error')));
      }
    }
  }
}
