import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';
import '../../personnel/domain/personnel_options.dart';

class AttendanceGroupStatusBadge extends StatelessWidget {
  const AttendanceGroupStatusBadge({required this.enabled, super.key});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.helper;
    final background = enabled ? AppColors.lightGreen : AppColors.background;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle_outline : Icons.pause_circle_outline,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            enabled ? '启用中' : '已停用',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class AttendanceGroupEmptyState extends StatelessWidget {
  const AttendanceGroupEmptyState({required this.onCreate, super.key});

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
                color: AppColors.lightBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_2_outlined,
                color: AppColors.techBlue,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text('还没有考勤组', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '先创建一个手动考勤组，再为人员配置默认考勤组。\n“全部临时工”会继续使用动态筛选，不单独建组。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新增考勤组'),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceGroupErrorState extends StatelessWidget {
  const AttendanceGroupErrorState({required this.onRetry, super.key});

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
            Text('考勤组数据暂时不可用', style: Theme.of(context).textTheme.titleLarge),
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

String employeeStatusLabel(EmployeeStatus status) {
  return PersonnelOptions.statusLabel(status);
}
