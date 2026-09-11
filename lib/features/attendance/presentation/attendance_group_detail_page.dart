import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../personnel/application/personnel_providers.dart';
import '../application/attendance_group_providers.dart';
import '../domain/attendance_group_options.dart';
import 'attendance_group_widgets.dart';

class AttendanceGroupDetailPage extends ConsumerWidget {
  const AttendanceGroupDetailPage({required this.groupId, super.key});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(attendanceGroupProvider(groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('考勤组详情'),
        actions: [
          group.maybeWhen(
            data: (item) => item == null
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () =>
                        context.push('/attendance/groups/$groupId/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '编辑考勤组',
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: group.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AttendanceGroupErrorState(
          onRetry: () => ref.invalidate(attendanceGroupProvider(groupId)),
        ),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('考勤组不存在或已被移除'));
          }
          return _GroupDetailContent(group: item, groupId: groupId);
        },
      ),
    );
  }
}

class _GroupDetailContent extends ConsumerWidget {
  const _GroupDetailContent({required this.group, required this.groupId});

  final AttendanceGroup group;
  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(attendanceGroupMembersProvider(groupId));
    return members.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => AttendanceGroupErrorState(
        onRetry: () => ref.invalidate(attendanceGroupMembersProvider(groupId)),
      ),
      data: (items) {
        final memberIds = items.map((item) => item.employee.id).toSet();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _GroupHeader(group: group, memberCount: items.length),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('组成员', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${items.length} 人',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!group.isEnabled)
              Card(
                color: AppColors.lightOrange,
                child: const Padding(
                  padding: EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFE98500)),
                      SizedBox(width: 10),
                      Expanded(child: Text('考勤组已停用，启用后才能新增或移出成员。')),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddMemberSheet(context, ref, memberIds),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('添加成员并设为默认组'),
                ),
              ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _GroupMembersEmpty()
            else
              for (final member in items) ...[
                _MemberCard(
                  member: member,
                  enabled: group.isEnabled,
                  onRemove: () => _removeMember(context, ref, member),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  Future<void> _showAddMemberSheet(
    BuildContext context,
    WidgetRef ref,
    Set<int> memberIds,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _AddMemberSheet(groupId: groupId, existingMemberIds: memberIds),
    );
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    AttendanceGroupMemberView member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出考勤组？'),
        content: Text('移出后，${member.employee.name} 将暂时没有默认考勤组，之后可以重新指定。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref
          .read(attendanceGroupRepositoryProvider)
          .clearEmployeeFromGroup(
            employeeId: member.employee.id,
            groupId: groupId,
          );
      ref.invalidate(employeeProvider(member.employee.id));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('移出失败：$error')));
      }
    }
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.memberCount});

  final AttendanceGroup group;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: group.isEnabled ? AppColors.primary : AppColors.helper,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.groups_2_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AttendanceGroupStatusBadge(enabled: group.isEnabled),
                    const SizedBox(width: 8),
                    Text(
                      '$memberCount 名成员',
                      style: Theme.of(context).textTheme.bodyMedium,
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

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.enabled,
    required this.onRemove,
  });

  final AttendanceGroupMemberView member;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final employee = member.employee;
    final detail = [
      employee.employeeNo,
      if (employee.position?.isNotEmpty ?? false) employee.position!,
      employeeStatusLabel(employee.status),
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.techBlue,
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
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (member.membership.isDefault) ...[
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.verified_outlined,
                          color: AppColors.primary,
                          size: 17,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            IconButton(
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: '移出考勤组',
              color: AppColors.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMembersEmpty extends StatelessWidget {
  const _GroupMembersEmpty();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.person_add_alt_1_outlined,
              color: AppColors.helper,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text('还没有组成员', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              '添加人员后，该考勤组会成为其默认考勤组。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  const _AddMemberSheet({
    required this.groupId,
    required this.existingMemberIds,
  });

  final int groupId;
  final Set<int> existingMemberIds;

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(attendanceGroupAssignableEmployeesProvider);
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
              Text('添加成员', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(
                '选择后会自动设为该人员的默认考勤组。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: '搜索姓名、编号或岗位',
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
                    final normalized = _search.trim().toLowerCase();
                    final filtered = items.where((employee) {
                      if (widget.existingMemberIds.contains(employee.id)) {
                        return false;
                      }
                      if (normalized.isEmpty) {
                        return true;
                      }
                      return employee.name.toLowerCase().contains(normalized) ||
                          employee.employeeNo.toLowerCase().contains(
                            normalized,
                          ) ||
                          (employee.position?.toLowerCase().contains(
                                normalized,
                              ) ??
                              false);
                    }).toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          '没有可添加的人员',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final employee = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.lightBlue,
                            foregroundColor: AppColors.techBlue,
                            child: const Icon(Icons.person_outline),
                          ),
                          title: Text(employee.name),
                          subtitle: Text(
                            '${employee.employeeNo} · ${employee.position ?? '岗位未填写'}',
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _assign(context, employee),
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

  Future<void> _assign(BuildContext context, Employee employee) async {
    try {
      await ref
          .read(attendanceGroupRepositoryProvider)
          .assignEmployeeToGroup(
            employeeId: employee.id,
            groupId: widget.groupId,
          );
      ref.invalidate(employeeProvider(employee.id));
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${employee.name} 已设为该组默认成员')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('添加失败：$error')));
      }
    }
  }
}
