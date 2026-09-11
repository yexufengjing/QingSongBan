import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';
import '../domain/personnel_options.dart';

class EmployeeStatusBadge extends StatelessWidget {
  const EmployeeStatusBadge({
    required this.status,
    this.deleted = false,
    this.compact = false,
    super.key,
  });

  final EmployeeStatus status;
  final bool deleted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (deleted
        ? EmployeeStatus.terminated
        : status) {
      EmployeeStatus.active => (
        AppColors.lightGreen,
        AppColors.primary,
        Icons.check_circle_outline,
      ),
      EmployeeStatus.paused => (
        AppColors.lightBlue,
        AppColors.techBlue,
        Icons.pause_circle_outline,
      ),
      EmployeeStatus.terminated => (
        AppColors.lightDanger,
        AppColors.danger,
        Icons.remove_circle_outline,
      ),
    };
    final label = deleted ? '已删除' : PersonnelOptions.statusLabel(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: compact ? 14 : 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class PersonnelSectionTitle extends StatelessWidget {
  const PersonnelSectionTitle({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        ?action,
      ],
    );
  }
}

class PersonnelEmptyState extends StatelessWidget {
  const PersonnelEmptyState({required this.onCreate, super.key});

  final VoidCallback onCreate;

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
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_outlined,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text('暂无人员档案', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '先建立一条档案，后续考勤组和月度名单才能继续配置。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新增人员'),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonnelErrorState extends StatelessWidget {
  const PersonnelErrorState({required this.onRetry, super.key});

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
            Text('人员数据暂时不可用', style: Theme.of(context).textTheme.titleLarge),
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
