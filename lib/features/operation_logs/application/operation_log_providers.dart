import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/operation_log_repository.dart';

final operationLogRepositoryProvider = Provider<OperationLogRepository>((ref) {
  return OperationLogRepository(ref.watch(appDatabaseProvider));
});

final operationLogsProvider = StreamProvider.autoDispose<List<OperationLog>>((
  ref,
) {
  return ref.watch(operationLogRepositoryProvider).watchLogs();
});
