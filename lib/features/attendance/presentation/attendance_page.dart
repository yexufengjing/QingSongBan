import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '考勤',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '每日考勤、月考勤表与考勤组',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('每日考勤', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const _AttendanceIcon(
                        Icons.calendar_month_outlined,
                        AppColors.techBlue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '按日期和考勤组登记上午、下午状态',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '修改后自动保存',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('attendance-daily-entry'),
                    onPressed: () => context.push('/attendance/daily'),
                    child: const Text('开始登记'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _AttendanceSection(
            title: '名单设置',
            entries: [
              (
                '月度名单',
                '维护本月考勤范围',
                Icons.groups_outlined,
                AppColors.techBlue,
                '/attendance/monthly-roster',
              ),
              (
                '考勤组',
                '设置人员默认考勤组',
                Icons.settings_outlined,
                AppColors.success,
                '/attendance/groups',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AttendanceSection(
            title: '记录查询',
            entries: [
              (
                '月考勤表',
                '查看每日状态',
                Icons.description_outlined,
                AppColors.techBlue,
                '/attendance/monthly-table',
              ),
              (
                '请假记录',
                '查看与登记请假',
                Icons.event_available_outlined,
                Color(0xFFE98500),
                '/attendance/leave',
              ),
              (
                '加班记录',
                '查看与登记加班',
                Icons.schedule_outlined,
                AppColors.purple,
                '/attendance/overtime',
              ),
              (
                '离职管理',
                '登记离职与交接',
                Icons.person_remove_outlined,
                AppColors.danger,
                '/attendance/termination',
              ),
              (
                '月度汇总',
                '查看出勤、请假与加班汇总',
                Icons.bar_chart_outlined,
                AppColors.success,
                '/reports',
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.title, required this.entries});
  final String title;
  final List<(String, String, IconData, Color, String)> entries;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              minTileHeight: 64,
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
              key: Key(
                entries[i].$5 == '/reports'
                    ? 'attendance-reports-entry'
                    : entries[i].$5 == '/attendance/groups'
                    ? 'attendance-groups-entry'
                    : entries[i].$5 == '/attendance/monthly-roster'
                    ? 'attendance-monthly-roster-entry'
                    : entries[i].$5,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              leading: _AttendanceIcon(entries[i].$3, entries[i].$4),
              title: Text(
                entries[i].$1,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(entries[i].$2),
              trailing: const Icon(Icons.chevron_right, color: AppColors.body),
              onTap: () => context.push(entries[i].$5),
            ),
          ],
        ],
      ),
    ),
  );
}

class _AttendanceIcon extends StatelessWidget {
  const _AttendanceIcon(this.icon, this.color);
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 24),
  );
}
