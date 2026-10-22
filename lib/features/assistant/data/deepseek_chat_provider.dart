import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/assistant_providers.dart';
import '../domain/assistant_chat_models.dart';
import 'deepseek_search_provider.dart';
import 'assistant_chat_errors.dart';
import '../domain/assistant_models.dart' show AssistantKeyStore, RequestToken;

export 'assistant_chat_errors.dart';

final assistantChatTransportProvider = Provider<AssistantChatTransport>(
  (ref) => DeepSeekSseTransport(),
);

final deepSeekChatProvider = Provider<DeepSeekChatProvider>((ref) {
  return DeepSeekChatProvider(
    keyStore: ref.watch(assistantKeyStoreProvider),
    transport: ref.watch(assistantChatTransportProvider),
  );
});

final deepSeekSearchProvider = Provider<DeepSeekSearchProvider>((ref) {
  return DeepSeekSearchProvider(keyStore: ref.watch(assistantKeyStoreProvider));
});

class AssistantChatChunk {
  const AssistantChatChunk({
    this.content = '',
    this.reasoningContent = '',
    this.searchSources = const [],
    this.searchPerformed = false,
    this.inputTokens,
    this.outputTokens,
    this.done = false,
  });

  final String content;
  final String reasoningContent;
  final List<AssistantSearchSource> searchSources;
  final bool searchPerformed;
  final int? inputTokens;
  final int? outputTokens;
  final bool done;
}

abstract interface class AssistantChatTransport {
  Stream<AssistantChatChunk> stream({
    required Uri uri,
    required String apiKey,
    required AssistantChatSettings settings,
    required List<AssistantChatMessage> messages,
    required RequestToken token,
  });
}

class DeepSeekChatProvider {
  DeepSeekChatProvider({required this._keyStore, required this._transport});

  final AssistantKeyStore _keyStore;
  final AssistantChatTransport _transport;

  Stream<AssistantChatChunk> streamChat(
    AssistantChatSettings settings,
    List<AssistantChatMessage> messages,
    RequestToken token, {
    List<AssistantSearchSource> searchSources = const [],
    bool searchPerformed = false,
  }) async* {
    final key = await _keyStore.readKey();
    if (token.isCancelled) throw const AssistantChatCancelled();
    if (key == null || key.trim().isEmpty) {
      throw const AssistantChatException('请先在助手设置中填写 DeepSeek API Key。');
    }
    final uri = _chatUri(settings.baseUrl);
    var attachedSources = false;
    await for (final chunk in _transport.stream(
      uri: uri,
      apiKey: key.trim(),
      settings: settings,
      messages: List.unmodifiable(messages),
      token: token,
    )) {
      if (!attachedSources && (searchPerformed || searchSources.isNotEmpty)) {
        attachedSources = true;
        yield AssistantChatChunk(
          content: chunk.content,
          reasoningContent: chunk.reasoningContent,
          searchSources: searchSources,
          searchPerformed: searchPerformed,
          inputTokens: chunk.inputTokens,
          outputTokens: chunk.outputTokens,
          done: chunk.done,
        );
      } else {
        yield chunk;
      }
    }
  }

  Future<void> checkConnection(
    AssistantChatSettings settings,
    RequestToken token,
  ) async {
    var receivedText = false;
    await for (final chunk in streamChat(settings, const [
      AssistantChatMessage(role: 'user', content: 'Reply with OK.'),
    ], token)) {
      if (chunk.content.isNotEmpty) receivedText = true;
      if (chunk.done) break;
    }
    if (!receivedText) {
      throw const AssistantChatException('连接成功，但模型没有返回文本。');
    }
  }

  Uri _chatUri(String baseUrl) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null || !base.hasScheme || base.host.isEmpty) {
      throw const AssistantChatException('API 地址无效，请填写完整的 http 或 https 地址。');
    }
    final cleanPath = base.path.replaceFirst(RegExp(r'/+$'), '');
    final path = cleanPath.endsWith('/chat/completions')
        ? cleanPath
        : '$cleanPath/chat/completions';
    return base.replace(path: path, query: null, fragment: null);
  }
}

class DeepSeekSseTransport implements AssistantChatTransport {
  DeepSeekSseTransport({
    HttpClient? client,
    this.timeout = const Duration(seconds: 90),
  }) : _clientOverride = client;

  final HttpClient? _clientOverride;
  final Duration timeout;

  @override
  Stream<AssistantChatChunk> stream({
    required Uri uri,
    required String apiKey,
    required AssistantChatSettings settings,
    required List<AssistantChatMessage> messages,
    required RequestToken token,
  }) async* {
    final client = _clientOverride ?? HttpClient();
    final ownsClient = _clientOverride == null;
    HttpClientRequest? request;
    var completed = false;
    final detachCancellation = token.addCancelHandler(() {
      if (request case final currentRequest?) {
        currentRequest.abort(const AssistantChatCancelled());
      } else if (ownsClient) {
        client.close(force: true);
      }
    });
    try {
      if (token.isCancelled) throw const AssistantChatCancelled();
      request = await client.postUrl(uri).timeout(timeout);
      if (token.isCancelled) {
        request.abort(const AssistantChatCancelled());
        throw const AssistantChatCancelled();
      }
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
        ..contentType = ContentType.json
        ..set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.write(
        jsonEncode({
          'model': settings.model,
          'messages': messages
              .map(
                (message) => {'role': message.role, 'content': message.content},
              )
              .toList(growable: false),
          'stream': true,
          'stream_options': {'include_usage': true},
          'max_tokens': settings.maxTokens,
          'thinking': {
            'type': settings.thinkingEnabled ? 'enabled' : 'disabled',
          },
          if (settings.thinkingEnabled)
            'reasoning_effort': settings.reasoningEffort,
        }),
      );
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>().timeout(timeout);
        throw AssistantChatException(_httpError(response.statusCode));
      }
      await for (final chunk in parseDeepSeekSse(response.timeout(timeout))) {
        if (token.isCancelled) throw const AssistantChatCancelled();
        yield chunk;
        if (chunk.done) {
          completed = true;
          return;
        }
      }
      if (!completed && !token.isCancelled) {
        throw const AssistantChatException('连接已关闭，回复流没有正常结束。');
      }
    } on TimeoutException {
      request?.abort();
      throw const AssistantChatException('DeepSeek 请求超时，请检查网络后重试。');
    } on SocketException catch (error) {
      throw AssistantChatException('网络连接失败：${error.message}');
    } on AssistantChatCancelled {
      rethrow;
    } on AssistantChatException {
      rethrow;
    } catch (error) {
      if (token.isCancelled) throw const AssistantChatCancelled();
      throw AssistantChatException('DeepSeek 请求失败：$error');
    } finally {
      detachCancellation();
      if (!completed && (token.isCancelled || request != null)) {
        request?.abort();
      }
      if (ownsClient) client.close(force: true);
    }
  }

  String _httpError(int status) {
    if (status == 401) return 'DeepSeek 认证失败（HTTP 401），请检查 API Key。';
    if (status == 403) return '访问被拒绝（HTTP 403），请检查账户权限和网络访问限制。';
    if (status == 402) return 'DeepSeek 账户余额不足，请检查账户额度。';
    if (status == 404) return 'API 地址或模型不存在，请检查自定义配置。';
    if (status == 400) return 'DeepSeek 拒绝了请求，请检查模型与参数配置。';
    if (status == 429) return 'DeepSeek 请求过于频繁，请稍后重试。';
    if (status >= 500) return 'DeepSeek 服务暂时不可用（$status）。';
    return 'DeepSeek 请求失败（$status）。';
  }
}

Stream<AssistantChatChunk> parseDeepSeekSse(Stream<List<int>> bytes) async* {
  var eventData = <String>[];
  await for (final line
      in utf8.decoder.bind(bytes).transform(const LineSplitter())) {
    if (line.isEmpty) {
      final event = _decodeSseEvent(eventData);
      eventData = [];
      if (event != null) {
        yield event;
        if (event.done) return;
      }
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      eventData.add(value.startsWith(' ') ? value.substring(1) : value);
    } else if (line.startsWith('event:') &&
        line.substring(6).trim() == 'error') {
      eventData.add('');
    }
  }
  if (eventData.isNotEmpty) {
    final event = _decodeSseEvent(eventData);
    if (event != null) yield event;
  }
}

AssistantChatChunk? _decodeSseEvent(List<String> dataLines) {
  if (dataLines.isEmpty) return null;
  final data = dataLines.join('\n').trim();
  if (data.isEmpty) return null;
  if (data == '[DONE]') return const AssistantChatChunk(done: true);
  final decoded = jsonDecode(data) as Map;
  if (decoded['error'] is Map) {
    throw const AssistantChatException('DeepSeek 流式请求失败，请检查配置后重试。');
  }
  final choices = decoded['choices'] as List? ?? const [];
  final delta = choices.isEmpty
      ? null
      : (choices.first as Map)['delta'] as Map?;
  final usage = decoded['usage'] as Map?;
  return AssistantChatChunk(
    content: delta?['content'] as String? ?? '',
    reasoningContent: delta?['reasoning_content'] as String? ?? '',
    inputTokens: (usage?['prompt_tokens'] as num?)?.toInt(),
    outputTokens: (usage?['completion_tokens'] as num?)?.toInt(),
  );
}
