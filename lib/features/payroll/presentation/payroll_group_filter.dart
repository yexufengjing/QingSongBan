import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/payroll_providers.dart';

class PayrollGroupFilter extends ConsumerWidget {
  const PayrollGroupFilter({required this.batchId, super.key});

  final int batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(payrollBatchGroupsProvider(batchId));
    return groups.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, _) => const SizedBox.shrink(),
      data: (values) {
        if (values.isEmpty) return const SizedBox.shrink();
        final selected = ref.watch(payrollGroupFilterProvider(batchId));
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DropdownButtonFormField<int?>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: '考勤组筛选'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('全部临时工')),
              for (final group in values)
                DropdownMenuItem<int?>(
                  value: group.id,
                  child: Text(group.name),
                ),
            ],
            onChanged: (value) =>
                ref.read(payrollGroupFilterProvider(batchId).notifier).state =
                    value,
          ),
        );
      },
    );
  }
}
