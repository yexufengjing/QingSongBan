import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class OperationLogRepository {
  const OperationLogRepository(this._database);

  final AppDatabase _database;

  Stream<List<OperationLog>> watchLogs() {
    return (_database.select(_database.operationLogs)..orderBy([
          (table) => OrderingTerm(
            expression: table.createdAt,
            mode: OrderingMode.desc,
          ),
        ]))
        .watch();
  }

  Future<void> record({
    required String operationType,
    required String entityType,
    int? entityId,
    String? detail,
  }) async {
    await _database
        .into(_database.operationLogs)
        .insert(
          OperationLogsCompanion.insert(
            operationType: operationType,
            entityType: entityType,
            entityId: Value(entityId),
            detail: Value(detail),
          ),
        );
  }
}
