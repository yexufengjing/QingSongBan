import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/assistant_attendance_reader.dart';
import '../data/assistant_business_reader.dart';
import '../data/assistant_key_store.dart';
import '../data/assistant_vehicle_expense_reader.dart';
import '../data/deepseek_provider.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_quick_query.dart';
import 'assistant_controller.dart';

final assistantKeyStoreProvider = Provider<AssistantKeyStore>(
  (ref) => SecureAssistantKeyStore(),
);

final assistantKeyConfiguredProvider = FutureProvider<bool>(
  (ref) => ref.watch(assistantKeyStoreProvider).hasKey(),
);

final deepSeekProvider = Provider<DeepSeekProvider>((ref) {
  return DeepSeekProvider(keyStore: ref.watch(assistantKeyStoreProvider));
});

final assistantAIProvider = Provider<AIProvider>((ref) {
  return ref.watch(deepSeekProvider);
});

final assistantAttendanceReaderProvider = Provider<AttendanceReadPort>((ref) {
  return AssistantAttendanceReader(ref.watch(appDatabaseProvider));
});

final assistantVehicleExpenseReaderProvider = Provider<VehicleExpenseReadPort>((
  ref,
) {
  return AssistantVehicleExpenseReader(ref.watch(appDatabaseProvider));
});

final assistantBusinessReaderProvider = Provider<AssistantBusinessReadPort>((ref) {
  return AssistantBusinessReader(ref.watch(appDatabaseProvider));
});

final assistantControllerProvider =
    NotifierProvider<AssistantSessionNotifier, AssistantState>(
      AssistantSessionNotifier.new,
    );

class AssistantSessionNotifier extends Notifier<AssistantState> {
  late AssistantController _controller;

  @override
  AssistantState build() {
    _controller = AssistantController(
      provider: ref.watch(assistantAIProvider),
      attendance: ref.watch(assistantAttendanceReaderProvider),
      expenseReader: ref.watch(assistantVehicleExpenseReaderProvider),
      businessReader: ref.watch(assistantBusinessReaderProvider),
    );
    _controller.onStateChanged = (next) => state = next;
    ref.onDispose(_controller.cancelCurrentTask);
    return _controller.state;
  }

  Future<void> submit(String utterance) => _controller.submit(utterance);

  Future<void> runQuickQuery(AssistantQuickQuery query) =>
      _controller.runQuickQuery(query);

  Future<void> runFollowUp(
    int messageId, {
    String? yearMonth,
    String? operation,
  }) => _controller.runFollowUp(
    messageId,
    yearMonth: yearMonth,
    operation: operation,
  );

  Future<void> selectCandidate(String candidateRef) =>
      _controller.selectCandidate(candidateRef);

  Future<void> refreshResult(String resultRef) =>
      _controller.refreshResult(resultRef);

  Future<void> explainAnswer(String resultRef) =>
      _controller.explainAnswer(resultRef);

  Future<void> loadNextVehicleRankingPage(String resultRef, String cursor) =>
      _controller.loadNextVehicleRankingPage(resultRef, cursor);

  Future<void> openRankedVehicle(String resultRef, int vehicleId) =>
      _controller.openRankedVehicle(resultRef, vehicleId);

  Future<void> selectClarificationMonth(String yearMonth) =>
      _controller.selectClarificationMonth(yearMonth);

  void updatePageContext(AssistantPageContext? context) =>
      _controller.updatePageContext(context);

  void cancelCurrentTask() => _controller.cancelCurrentTask();

  void clearSession() => _controller.clearSession();
}
