import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/stage_placeholder_card.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('汇总', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text(
              '月度考勤、人员变动与异常检查',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const StagePlaceholderCard(
              icon: Icons.bar_chart_outlined,
              title: '汇总入口已建立',
              description: '月度汇总会在上午/下午考勤、考勤组和月度名单完成后接入，避免提前绑定不稳定的数据模型。',
              accent: AppColors.purple,
            ),
          ],
        ),
      ),
    );
  }
}
