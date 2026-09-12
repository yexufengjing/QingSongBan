import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/operation_logs/data/operation_log_repository.dart';

void main() {
  late AppDatabase database;
  late OperationLogRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = OperationLogRepository(database);
  });

  tearDown(() => database.close());

  test('records and streams an operation log', () async {
    await repository.record(
      operationType: 'unlock',
      entityType: 'monthlySummary',
      entityId: 3,
      detail: '测试解锁',
    );
    final logs = await repository.watchLogs().first;
    expect(logs, hasLength(1));
    expect(logs.single.operationType, 'unlock');
    expect(logs.single.entityId, 3);
  });
}
