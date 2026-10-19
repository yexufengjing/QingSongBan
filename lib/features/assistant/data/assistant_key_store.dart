import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/assistant_models.dart';

abstract interface class AssistantSecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterAssistantSecureStorage implements AssistantSecureStorage {
  FlutterAssistantSecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'assistant.deepseek'),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stores only the DeepSeek API key used by the assistant provider.
class SecureAssistantKeyStore implements AssistantKeyStore {
  SecureAssistantKeyStore({AssistantSecureStorage? storage})
    : _storage = storage ?? FlutterAssistantSecureStorage();

  static const keyName = 'assistant.deepseek.apiKey';

  final AssistantSecureStorage _storage;

  @override
  Future<bool> hasKey() async => (await readKey())?.isNotEmpty ?? false;

  @override
  Future<String?> readKey() => _storage.read(keyName);

  @override
  Future<void> saveKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(key, 'key', 'API Key cannot be empty.');
    }
    await _storage.write(keyName, trimmed);
  }

  @override
  Future<void> removeKey() => _storage.delete(keyName);
}
