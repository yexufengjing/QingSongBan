import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/data/assistant_key_store.dart';

void main() {
  test('stores and removes only the dedicated DeepSeek API key', () async {
    final storage = _MemorySecureStorage()
      ..values['unrelated.setting'] = 'keep';
    final keyStore = SecureAssistantKeyStore(storage: storage);

    await keyStore.saveKey('  user-key  ');

    expect(await keyStore.hasKey(), isTrue);
    expect(await keyStore.readKey(), 'user-key');
    expect(storage.values, {
      'unrelated.setting': 'keep',
      SecureAssistantKeyStore.keyName: 'user-key',
    });

    await keyStore.removeKey();

    expect(await keyStore.hasKey(), isFalse);
    expect(storage.values, {'unrelated.setting': 'keep'});
    expect(storage.deleteAllCalls, 0);
  });

  test('rejects an empty key before writing', () async {
    final storage = _MemorySecureStorage();
    final keyStore = SecureAssistantKeyStore(storage: storage);

    await expectLater(keyStore.saveKey('   '), throwsArgumentError);

    expect(storage.values, isEmpty);
  });
}

class _MemorySecureStorage implements AssistantSecureStorage {
  final values = <String, String>{};
  var deleteAllCalls = 0;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
