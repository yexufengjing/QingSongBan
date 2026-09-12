import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/termination_repository.dart';
import '../domain/termination_options.dart';

final terminationRepositoryProvider = Provider<TerminationRepository>((ref) {
  return TerminationRepository(ref.watch(appDatabaseProvider));
});

final terminationRecordsProvider =
    StreamProvider.autoDispose<List<TerminationRecordView>>((ref) {
      return ref.watch(terminationRepositoryProvider).watchTerminations();
    });
