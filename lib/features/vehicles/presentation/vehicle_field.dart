import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

/// Keeps labels visible while a vehicle form is empty, focused, or filled.
class VehicleField extends StatelessWidget {
  const VehicleField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label.replaceAll(' *', ''),
              style: const TextStyle(color: AppColors.body, fontSize: 14),
            ),
            if (label.endsWith(' *'))
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.danger, fontSize: 14),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}
