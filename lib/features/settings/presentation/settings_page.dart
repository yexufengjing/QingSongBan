import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/design_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Center(
          child: Text('我的', style: Theme.of(context).textTheme.headlineMedium),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const DesignIcon(
              Icons.notifications_none_outlined,
              color: AppColors.warning,
              size: 48,
            ),
            title: const Text(
              '备忘提醒',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('事项与通知'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/reminders'),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ExpansionTile(
            key: const Key('settings-data-tools'),
            initiallyExpanded: true,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const DesignIcon(Icons.grid_view_rounded),
            title: const Text(
              '数据工具 · 3项',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            children: [
              const DesignGrid(
                columns: 3,
                children: [
                  _Tool(
                    '导入导出',
                    Icons.table_view_outlined,
                    AppColors.techBlue,
                    '/settings/excel',
                  ),
                  _Tool(
                    '备份与恢复',
                    Icons.backup_outlined,
                    AppColors.purple,
                    '/settings/backup',
                  ),
                  _Tool(
                    '操作日志',
                    Icons.history,
                    AppColors.body,
                    '/settings/operation-logs',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _Description('导入导出', '月度导出与人员名单导入'),
              const SizedBox(height: 8),
              const _Description('备份与恢复', '备份本地数据，恢复覆盖当前数据'),
              const SizedBox(height: 8),
              const _Description('操作日志', '查看操作记录'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const DesignSection(
          title: '业务设置',
          child: DesignGrid(
            columns: 2,
            children: [
              _Tool(
                '社保保险',
                Icons.shield_outlined,
                AppColors.techBlue,
                '/settings/insurance',
              ),
              _Tool(
                '临时工薪资',
                Icons.payments_outlined,
                AppColors.success,
                '/reports/payroll',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Tool extends StatelessWidget {
  const _Tool(this.title, this.icon, this.color, this.route);
  final String title, route;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF4FAFE),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 20),
        child: Column(
          children: [
            DesignIcon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Description extends StatelessWidget {
  const _Description(this.title, this.body);
  final String title, body;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$title — ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          TextSpan(
            text: body,
            style: const TextStyle(color: AppColors.body),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 14, height: 1.5),
    ),
  );
}
