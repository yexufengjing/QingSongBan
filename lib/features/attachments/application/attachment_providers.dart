import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/attachment_repository.dart';

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return AttachmentRepository(ref.watch(appDatabaseProvider));
});

final employeeAttachmentsProvider = FutureProvider.autoDispose
    .family<List<EmployeeAttachment>, int>((ref, employeeId) {
      return ref
          .watch(attachmentRepositoryProvider)
          .listForEmployee(employeeId);
    });

final employeeAttachmentCountProvider = FutureProvider.autoDispose
    .family<int, int>((ref, employeeId) {
      return ref
          .watch(attachmentRepositoryProvider)
          .listForEmployee(employeeId)
          .then((items) => items.length);
    });
