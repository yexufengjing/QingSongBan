import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/privacy_utils.dart';
import '../../attendance/application/attendance_group_providers.dart';
import '../../attachments/application/attachment_providers.dart';
import '../application/personnel_providers.dart';
import '../domain/personnel_options.dart';
import 'personnel_widgets.dart';

class PersonnelDetailPage extends ConsumerWidget {
  const PersonnelDetailPage({required this.employeeId, super.key});

  final int employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(employeeProvider(employeeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('人员详情'),
        actions: [
          employee.maybeWhen(
            data: (item) => item == null || item.isDeleted
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () =>
                        context.push('/personnel/$employeeId/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '编辑档案',
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          employee.maybeWhen(
            data: (item) => item == null
                ? const SizedBox.shrink()
                : PopupMenuButton<_DetailAction>(
                    onSelected: (action) => _handleAction(context, ref, action),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: item.isDeleted
                            ? _DetailAction.restore
                            : _DetailAction.delete,
                        child: Text(item.isDeleted ? '恢复档案' : '删除档案'),
                      ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: employee.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => PersonnelErrorState(
          onRetry: () => ref.invalidate(employeeProvider(employeeId)),
        ),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('档案不存在或已被移除'));
          }
          return _EmployeeDetailContent(employee: item);
        },
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _DetailAction action,
  ) async {
    if (action == _DetailAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除人员档案？'),
          content: const Text('档案会进入已删除列表，历史数据不会被清除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
      await ref.read(personnelRepositoryProvider).softDelete(employeeId);
      ref.invalidate(employeeProvider(employeeId));
      if (context.mounted) {
        context.pop();
      }
    } else {
      await ref.read(personnelRepositoryProvider).restore(employeeId);
      ref.invalidate(employeeProvider(employeeId));
    }
  }
}

enum _DetailAction { delete, restore }

class _EmployeeDetailContent extends ConsumerWidget {
  const _EmployeeDetailContent({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = employee.defaultAttendanceGroupId == null
        ? null
        : ref
              .watch(
                attendanceGroupProvider(employee.defaultAttendanceGroupId!),
              )
              .maybeWhen(data: (item) => item, orElse: () => null);
    final groupName = group == null
        ? '未设置'
        : group.isEnabled
        ? group.name
        : '${group.name}（已停用）';
    final attachmentCount =
        ref.watch(employeeAttachmentCountProvider(employee.id)).valueOrNull ??
        0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EmployeeIdentityCard(employee: employee),
          if (employee.isDeleted) ...[
            const SizedBox(height: 12),
            Card(
              color: AppColors.lightDanger,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.danger),
                    SizedBox(width: 10),
                    Expanded(child: Text('此档案已软删除，可从右上角恢复。')),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const PersonnelSectionTitle(title: '基本信息'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  _InfoRow(label: '性别', value: employee.gender ?? '未填写'),
                  _InfoRow(
                    label: '身份证号',
                    value: PrivacyUtils.maskIdCard(employee.idCardNumber),
                  ),
                  _InfoRow(
                    label: '出生日期',
                    value: employee.birthDate == null
                        ? '未填写'
                        : '${AppDateUtils.formatDate(employee.birthDate)} · ${AppDateUtils.ageAt(employee.birthDate!)} 岁',
                  ),
                  _InfoRow(
                    label: '联系电话',
                    value: PrivacyUtils.maskPhone(employee.phone),
                  ),
                  _InfoRow(label: '家庭住址', value: employee.address ?? '未填写'),
                  _InfoRow(
                    label: '备注',
                    value: employee.remark ?? '未填写',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const PersonnelSectionTitle(title: '附件资料'),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              key: const Key('personnel-attachments-entry'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              leading: const CircleAvatar(
                backgroundColor: AppColors.lightBlue,
                child: Icon(Icons.folder_outlined, color: AppColors.techBlue),
              ),
              title: const Text('统一附件中心'),
              subtitle: Text(
                attachmentCount == 0
                    ? '添加身份证、银行卡、保险或离职材料'
                    : '$attachmentCount 个有效附件',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/personnel/${employee.id}/attachments'),
            ),
          ),
          const SizedBox(height: 20),
          const PersonnelSectionTitle(title: '工作信息'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  _InfoRow(
                    label: '入职日期',
                    value: AppDateUtils.formatDate(employee.hireDate),
                  ),
                  _InfoRow(
                    label: '人员状态',
                    value: PersonnelOptions.statusLabel(employee.status),
                  ),
                  _InfoRow(label: '岗位', value: employee.position ?? '未填写'),
                  _InfoRow(label: '所属班组', value: employee.team ?? '未填写'),
                  _InfoRow(label: '工作区域', value: employee.workArea ?? '未填写'),
                  _InfoRow(label: '负责人', value: employee.manager ?? '未填写'),
                  _InfoRow(
                    label: '用工类型',
                    value: employee.employmentType ?? '未填写',
                  ),
                  _InfoRow(label: '默认考勤组', value: groupName, isLast: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              key: const Key('personnel-payroll-entry'),
              leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
              title: const Text('工资记录'),
              subtitle: const Text('维护工资工种、日薪和历史工资'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/personnel/${employee.id}/payroll'),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '身份证号和联系电话默认脱敏显示。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EmployeeIdentityCard extends StatelessWidget {
  const _EmployeeIdentityCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: employee.isDeleted
              ? const [Color(0xFFFFF3F3), Color(0xFFFFECEC)]
              : const [Color(0xFFE8F7F0), Color(0xFFE8F1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: employee.isDeleted ? AppColors.danger : AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              employee.isDeleted
                  ? Icons.person_off_outlined
                  : Icons.person_outline,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  employee.employeeNo,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                EmployeeStatusBadge(
                  status: employee.status,
                  deleted: employee.isDeleted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
