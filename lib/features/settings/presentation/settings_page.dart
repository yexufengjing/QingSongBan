import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/stage_placeholder_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('我的', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text('本地设置、提醒和备份恢复', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            const StagePlaceholderCard(
              icon: Icons.settings_outlined,
              title: '个人中心入口已建立',
              description: '本地提醒、备份恢复和应用设置将在后续执行阶段接入。',
              accent: AppColors.body,
            ),
          ],
        ),
      ),
    );
  }
}
