import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/assistant_chat_models.dart';
import '../domain/assistant_models.dart' show AssistantKeyStore, RequestToken;
import 'assistant_chat_errors.dart';

const _searchEndpoint = 'https://api.deepseek.com/v1/tools/search';
const _searchModels = {'deepseek-flash', 'deepseek-v4-pro'};

bool supportsDeepSeekSearch(AssistantChatSettings settings) {
  final uri = Uri.tryParse(settings.baseUrl.trim());
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.toLowerCase() == 'api.deepseek.com' &&
      (uri.port == 443 || uri.hasPort == false) &&
      _searchModels.contains(settings.model.trim());
}

bool supportsDeepSeekThinking(AssistantChatSettings settings) =>
    supportsDeepSeekSearch(settings);

class AssistantSearchResult {
  const AssistantSearchResult({required this.sources, required this.context});

  final List<AssistantSearchSource> sources;
  final String context;
}

typedef DeepSeekSearchCall = Future<DeepSeekSearchResponse> Function({
  required Uri uri,
  required String apiKey,
  required String query,
  required RequestToken token,
  required Duration timeout,
});

class DeepSeekSearchResponse {
  const DeepSeekSearchResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class DeepSeekSearchProvider {
  DeepSeekSearchProvider({
    required this._keyStore,
    DeepSeekSearchCall? call,
    this.timeout = const Duration(seconds: 20),
  }) : _call = call ?? _httpCall;

  final AssistantKeyStore _keyStore;
  final DeepSeekSearchCall _call;
  final Duration timeout;

  static bool supports(AssistantChatSettings settings) {
    return supportsDeepSeekSearch(settings);
  }

  Future<AssistantSearchResult> search({
    required AssistantChatSettings settings,
    required String question,
    required RequestToken token,
  }) async {
    if (!supports(settings)) {
      throw const AssistantChatException(
        '联网搜索仅支持官方 DeepSeek API 地址和 deepseek-flash / deepseek-v4-pro 模型。',
      );
    }
    if (token.isCancelled) throw const AssistantChatCancelled();
    final key = await _keyStore.readKey();
    if (token.isCancelled) throw const AssistantChatCancelled();
    if (key == null || key.trim().isEmpty) {
      throw const AssistantChatException('请先在助手设置中填写 DeepSeek API Key。');
    }
    final runes = question.runes.toList(growable: false);
    final query = String.fromCharCodes(runes.take(128));
    if (query.trim().isEmpty) {
      throw const AssistantChatException('联网搜索问题不能为空。');
    }
    late final DeepSeekSearchResponse response;
    try {
      response = await _call(
        uri: Uri.parse(_searchEndpoint),
        apiKey: key.trim(),
        query: query,
        token: token,
        timeout: timeout,
      );
    } on TimeoutException {
      if (token.isCancelled) throw const AssistantChatCancelled();
      throw const AssistantChatException('联网搜索超时，请检查网络后重试。');
    } on AssistantChatCancelled {
      rethrow;
    } catch (_) {
      if (token.isCancelled) throw const AssistantChatCancelled();
      throw const AssistantChatException('联网搜索失败，请检查网络后重试。');
    }
    if (token.isCancelled) throw const AssistantChatCancelled();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AssistantChatException(_httpError(response.statusCode));
    }
    final Map decoded;
    try {
      decoded = jsonDecode(response.body) as Map;
    } catch (_) {
      throw const AssistantChatException('联网搜索返回格式无效，请稍后重试。');
    }
    final results = decoded['results'] as List? ?? const [];
    final sources = <AssistantSearchSource>[];
    final excerpts = <String>[];
    for (final raw in results.take(5)) {
      if (raw is! Map) continue;
      final url = raw['url'] as String? ?? '';
      final parsedUrl = Uri.tryParse(url);
      if (parsedUrl == null ||
          !const {'http', 'https'}.contains(parsedUrl.scheme.toLowerCase()) ||
          parsedUrl.host.isEmpty) {
        continue;
      }
      final title = (raw['title'] as String? ?? '').trim();
      final snippet = (raw['snippet'] as String? ?? '').trim();
      final text = ((raw['summary'] as String?)?.trim().isNotEmpty ?? false)
          ? (raw['summary'] as String).trim()
          : ((raw['content'] as String?)?.trim().isNotEmpty ?? false)
          ? (raw['content'] as String).trim()
          : snippet;
      final index = sources.length + 1;
      sources.add(
        AssistantSearchSource(title: title, url: url, snippet: snippet),
      );
      final excerpt = String.fromCharCodes(text.runes.take(2000));
      excerpts.add(
        '[$index] ${title.isEmpty ? url : title}\nURL: $url\n$excerpt',
      );
    }
    return AssistantSearchResult(
      sources: List.unmodifiable(sources),
      context: excerpts.join('\n\n'),
    );
  }

  static Future<DeepSeekSearchResponse> _httpCall({
    required Uri uri,
    required String apiKey,
    required String query,
    required RequestToken token,
    required Duration timeout,
  }) async {
    final client = HttpClient();
    HttpClientRequest? request;
    final detach = token.addCancelHandler(() {
      request?.abort(const AssistantChatCancelled());
      client.close(force: true);
    });
    try {
      if (token.isCancelled) throw const AssistantChatCancelled();
      request = await client
          .postUrl(uri)
          .timeout(
            timeout,
            onTimeout: () {
              request?.abort();
              throw TimeoutException('Search request timed out.');
            },
          );
      if (token.isCancelled) throw const AssistantChatCancelled();
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
        ..contentType = ContentType.json;
      request.write(
        jsonEncode({'query': query, 'count': 5, 'need_content': true}),
      );
      final response = await request.close().timeout(
        timeout,
        onTimeout: () {
          client.close(force: true);
          throw TimeoutException('Search request timed out.');
        },
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(
            timeout,
            onTimeout: () {
              request?.abort();
              throw TimeoutException('Search response timed out.');
            },
          );
      return DeepSeekSearchResponse(
        statusCode: response.statusCode,
        body: body,
      );
    } on SocketException {
      if (token.isCancelled) throw const AssistantChatCancelled();
      rethrow;
    } finally {
      detach();
      client.close(force: true);
    }
  }

  String _httpError(int status) {
    if (status == 401) return 'DeepSeek 认证失败（HTTP 401），请检查 API Key。';
    if (status == 402) return 'DeepSeek 账户余额不足，请检查账户额度。';
    if (status == 403) return 'DeepSeek 搜索访问被拒绝（HTTP 403）。';
    if (status == 429) return 'DeepSeek 搜索请求过于频繁，请稍后重试。';
    if (status >= 500) return 'DeepSeek 搜索服务暂时不可用（$status）。';
    return 'DeepSeek 搜索请求失败（$status）。';
  }
}
