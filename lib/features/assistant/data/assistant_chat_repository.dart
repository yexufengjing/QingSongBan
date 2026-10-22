import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/assistant_chat_models.dart';

const assistantChatSettingsKey = 'assistant_free_chat_settings_v1';
const assistantChatHistoryKey = 'assistant_free_chat_history_v1';

class AssistantChatHistory {
  AssistantChatHistory({
    required List<AssistantChatSession> sessions,
    this.currentSessionId,
  }) : sessions = List.unmodifiable(sessions);

  final List<AssistantChatSession> sessions;
  final String? currentSessionId;
}

abstract interface class AssistantChatRepository {
  Future<AssistantChatSettings> loadSettings();
  Future<void> saveSettings(AssistantChatSettings settings);
  Future<AssistantChatHistory> loadHistory();
  Future<void> saveHistory(AssistantChatHistory history);
}

final assistantChatRepositoryProvider = Provider<AssistantChatRepository>(
  (ref) => DriftAssistantChatRepository(ref.watch(appDatabaseProvider)),
);

class DriftAssistantChatRepository implements AssistantChatRepository {
  DriftAssistantChatRepository(this._database);

  final AppDatabase _database;

  @override
  Future<AssistantChatSettings> loadSettings() async {
    final row =
        await (_database.select(_database.appSettings)..where(
              (setting) => setting.settingKey.equals(assistantChatSettingsKey),
            ))
            .getSingleOrNull();
    final encoded = row?.settingValue;
    if (encoded == null || encoded.isEmpty) {
      return const AssistantChatSettings();
    }
    return AssistantChatSettings.fromJson(
      (jsonDecode(encoded) as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<void> saveSettings(AssistantChatSettings settings) =>
      _upsert(assistantChatSettingsKey, jsonEncode(settings.toJson()));

  @override
  Future<AssistantChatHistory> loadHistory() async {
    final row =
        await (_database.select(_database.appSettings)..where(
              (setting) => setting.settingKey.equals(assistantChatHistoryKey),
            ))
            .getSingleOrNull();
    final encoded = row?.settingValue;
    if (encoded == null || encoded.isEmpty) {
      return AssistantChatHistory(sessions: const []);
    }
    final decoded = (jsonDecode(encoded) as Map).cast<String, Object?>();
    final sessions = (decoded['sessions'] as List? ?? const [])
        .map(
          (item) => AssistantChatSession.fromJson(
            (item as Map).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
    final requestedId = decoded['currentSessionId'] as String?;
    final currentId = sessions.any((session) => session.id == requestedId)
        ? requestedId
        : sessions.firstOrNull?.id;
    return AssistantChatHistory(
      sessions: sessions,
      currentSessionId: currentId,
    );
  }

  @override
  Future<void> saveHistory(AssistantChatHistory history) => _upsert(
    assistantChatHistoryKey,
    jsonEncode({
      'currentSessionId': history.currentSessionId,
      'sessions': history.sessions.map((session) => session.toJson()).toList(),
    }),
  );

  Future<void> _upsert(String key, String value) async {
    await _database
        .into(_database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            settingKey: key,
            settingValue: Value(value),
          ),
          onConflict: DoUpdate(
            (_) => AppSettingsCompanion(settingValue: Value(value)),
            target: [_database.appSettings.settingKey],
          ),
        );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
