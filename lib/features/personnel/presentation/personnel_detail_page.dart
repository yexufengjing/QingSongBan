import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/privacy_utils.dart';
import '../../attendance/application/attendance_group_providers.dart';
import '../../attachments/application/attachment_providers.dart';
import '../../inventory/presentation/widgets/inventory_employee_history_section.dart';
import '../../insurance/application/insurance_providers.dart';
import '../../insurance/domain/insurance_options.dart';
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
      appBar: AppBar(title: const Text('人员档案'), centerTitle: false),
      body: employee.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => PersonnelErrorState(
          onRetry: () => ref.invalidate(employeeProvider(employeeId)),
        ),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('档案不存在或已被移除'));
          }
          return _EmployeeDetailContent(
            employee: item,
            onMore: (action) => _handleAction(context, ref, action),
          );
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
  const _EmployeeDetailContent({required this.employee, required this.onMore});

  final Employee employee;
  final ValueChanged<_DetailAction> onMore;

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
    final insuranceState = ref.watch(insuranceProfileProvider(employee.id));
    final insurance = insuranceState.valueOrNull;
    final insuranceChanges = ref.watch(
      insuranceEmployeeChangesProvider(employee.id),
    );
    final attachmentsState = ref.watch(
      employeeAttachmentsProvider(employee.id),
    );
    final attachments =
        attachmentsState.valueOrNull ?? const <EmployeeAttachment>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EmployeeIdentityCard(
            employee: employee,
            groupName: groupName,
            onMore: onMore,
          ),
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
          const SizedBox(height: 12),
          _DetailSection(
            title: '基本信息',
            icon: Icons.person_outline,
            iconColor: AppColors.primary,
            initiallyExpanded: true,
            rows: [
              ('姓名', employee.name),
              ('联系电话', PrivacyUtils.maskPhone(employee.phone)),
              ('身份证号', PrivacyUtils.maskIdCard(employee.idCardNumber)),
              ('当前住址', employee.address ?? '未填写'),
              (
                '出生/年龄',
                employee.birthDate == null
                    ? '未填写'
                    : '${AppDateUtils.formatDate(employee.birthDate)} · ${AppDateUtils.ageAt(employee.birthDate!)} 岁',
              ),
              ('备注', employee.remark ?? '未填写'),
              (
                '性别',
                employee.gender?.isNotEmpty == true ? employee.gender! : '未填写',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: '工作信息',
            icon: Icons.work_outline,
            iconColor: AppColors.techBlue,
            initiallyExpanded: true,
            rows: [
              ('入职日期', AppDateUtils.formatDate(employee.hireDate)),
              ('工作区域', employee.workArea ?? '未填写'),
              ('岗位', employee.position ?? '未填写'),
              ('负责人', employee.manager ?? '未填写'),
              ('班组', employee.team ?? '未填写'),
              ('用工类型', employee.employmentType ?? '未填写'),
              ('默认考勤组', groupName),
              ('人员状态', PersonnelOptions.statusLabel(employee.status)),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: '保险信息',
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFFE98500),
            initiallyExpanded: true,
            rows: [
              (
                '是否参保',
                insuranceState.when(
                  loading: () => '加载中',
                  error: (_, _) => '暂不可用',
                  data: (value) => value == null
                      ? '未设置'
                      : value.isInsured
                      ? '● 已参保'
                      : '未参保',
                ),
              ),
              (
                '参保开始',
                insuranceState.when(
                  loading: () => '加载中',
                  error: (_, _) => '暂不可用',
                  data: (_) => insurance?.effectiveMonth ?? '未填写',
                ),
              ),
              (
                '险种',
                insuranceState.when(
                  loading: () => '加载中',
                  error: (_, _) => '暂不可用',
                  data: (_) => insurance?.insuranceType == null
                      ? '未填写'
                      : InsuranceOptions.typeLabel(insurance!.insuranceType!),
                ),
              ),
              (
                '缴费基数',
                insuranceState.when(
                  loading: () => '加载中',
                  error: (_, _) => '暂不可用',
                  data: (_) => insurance?.contributionBase == null
                      ? '未填写'
                      : '¥${insurance!.contributionBase!.toStringAsFixed(2)}',
                ),
              ),
              (
                '最近变更',
                insuranceChanges.when(
                  loading: () => '加载中',
                  error: (_, _) => '暂不可用',
                  data: (items) => items.isEmpty
                      ? '暂无记录'
                      : '${items.first.change.effectiveMonth} · ${InsuranceOptions.changeTypeLabel(items.first.change.changeType)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AttachmentCategories(
            employeeId: employee.id,
            items: attachments,
            loading: attachmentsState.isLoading,
            error: attachmentsState.hasError,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _EmployeeActionButton(
                  label: '请假登记',
                  icon: Icons.event_busy_outlined,
                  color: const Color(0xFFE98500),
                  onTap: () => context.push('/attendance/leave/new'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EmployeeActionButton(
                  label: '加班登记',
                  icon: Icons.more_time_outlined,
                  color: AppColors.purple,
                  onTap: () => context.push('/attendance/overtime/new'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EmployeeActionButton(
                  label: '离职登记',
                  icon: Icons.person_remove_outlined,
                  color: AppColors.danger,
                  onTap: () => context.push('/attendance/termination/new'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InventoryEmployeeHistorySection(employeeId: employee.id),
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
  const _EmployeeIdentityCard({
    required this.employee,
    required this.groupName,
    required this.onMore,
  });

  final Employee employee;
  final String groupName;
  final ValueChanged<_DetailAction> onMore;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: employee.isDeleted
                ? AppColors.lightDanger
                : AppColors.lightBlue,
            child: Icon(
              employee.isDeleted
                  ? Icons.person_off_outlined
                  : Icons.person_outline,
              size: 34,
              color: employee.isDeleted ? AppColors.danger : AppColors.techBlue,
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
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(width: 7),
                    EmployeeStatusBadge(
                      status: employee.status,
                      deleted: employee.isDeleted,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${employee.position?.isNotEmpty == true ? employee.position : '岗位未填写'}  ·  $groupName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '工号：${employee.employeeNo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!employee.isDeleted)
                FilledButton.icon(
                  key: const Key('personnel-detail-edit'),
                  onPressed: () =>
                      context.push('/personnel/${employee.id}/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('编辑'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.techBlue,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              PopupMenuButton<_DetailAction>(
                tooltip: '更多档案操作',
                onSelected: onMore,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: employee.isDeleted
                        ? _DetailAction.restore
                        : _DetailAction.delete,
                    child: Text(employee.isDeleted ? '恢复档案' : '删除档案'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.more_horiz, size: 18),
                      SizedBox(width: 3),
                      Text('更多'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.rows,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<(String, String)> rows;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final row in rows)
                  SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(
                            row.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.body,
                              height: 1.3,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.$2,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              color: row.$1 == '是否参保' && row.$2.contains('已参保')
                                  ? AppColors.primary
                                  : AppColors.ink,
                              fontWeight:
                                  row.$1 == '是否参保' && row.$2.contains('已参保')
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AttachmentCategories extends StatelessWidget {
  const _AttachmentCategories({
    required this.employeeId,
    required this.items,
    required this.loading,
    required this.error,
  });

  final int employeeId;
  final List<EmployeeAttachment> items;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final categories = [
      ('身份证件', ['idFront', 'idBack'], Icons.badge_outlined, AppColors.techBlue),
      ('银行卡', ['bankCard'], Icons.credit_card_outlined, AppColors.primary),
      (
        '保险材料',
        ['insurance'],
        Icons.health_and_safety_outlined,
        const Color(0xFFE98500),
      ),
      ('离职材料', ['termination'], Icons.description_outlined, AppColors.purple),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              key: const Key('personnel-attachments-entry'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 2),
              leading: const Icon(Icons.attach_file, color: AppColors.purple),
              title: const Text('附件资料'),
              subtitle: Text(
                loading
                    ? '正在读取附件'
                    : error
                    ? '附件暂时不可用'
                    : '共 ${items.length} 项',
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.helper,
              ),
              onTap: () => context.push('/personnel/$employeeId/attachments'),
            ),
            Row(
              children: [
                for (final category in categories)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            context.push('/personnel/$employeeId/attachments'),
                        child: Container(
                          height: 86,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: category.$4.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(category.$3, color: category.$4, size: 21),
                              const SizedBox(height: 4),
                              Text(
                                category.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                loading || error
                                    ? '—'
                                    : '${items.where((item) => category.$2.contains(item.category)).length} 张',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _EmployeeActionButton extends StatelessWidget {
  const _EmployeeActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: FilledButton.styleFrom(
      foregroundColor: color,
      backgroundColor: color.withValues(alpha: .1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    ),
  );
}
