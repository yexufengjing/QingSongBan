import 'dart:convert';

class AssistantChatSettings {
  const AssistantChatSettings({
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-flash',
    this.defaultFreeChat = false,
    this.concise = true,
    this.fontScale = 1,
    this.contextTurns = 12,
    this.maxTokens = 4096,
    this.thinkingEnabled = false,
    this.reasoningEffort = 'high',
    this.searchEnabled = false,
  });

  final String baseUrl;
  final String model;
  final bool defaultFreeChat;
  final bool concise;
  final double fontScale;
  final int contextTurns;
  final int maxTokens;
  final bool thinkingEnabled;
  final String reasoningEffort;
  final bool searchEnabled;

  AssistantChatSettings copyWith({
    String? baseUrl,
    String? model,
    bool? defaultFreeChat,
    bool? concise,
    double? fontScale,
    int? contextTurns,
    int? maxTokens,
    bool? thinkingEnabled,
    String? reasoningEffort,
    bool? searchEnabled,
  }) => AssistantChatSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    defaultFreeChat: defaultFreeChat ?? this.defaultFreeChat,
    concise: concise ?? this.concise,
    fontScale: fontScale ?? this.fontScale,
    contextTurns: contextTurns ?? this.contextTurns,
    maxTokens: maxTokens ?? this.maxTokens,
    thinkingEnabled: thinkingEnabled ?? this.thinkingEnabled,
    reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    searchEnabled: searchEnabled ?? this.searchEnabled,
  );

  Map<String, Object?> toJson() => {
    'baseUrl': baseUrl,
    'model': model,
    'defaultFreeChat': defaultFreeChat,
    'concise': concise,
    'fontScale': fontScale,
    'contextTurns': contextTurns,
    'maxTokens': maxTokens,
    'thinkingEnabled': thinkingEnabled,
    'reasoningEffort': reasoningEffort,
    'searchEnabled': searchEnabled,
  };

  factory AssistantChatSettings.fromJson(Map<String, Object?> json) =>
      AssistantChatSettings(
        baseUrl: json['baseUrl'] as String? ?? 'https://api.deepseek.com',
        model: json['model'] as String? ?? 'deepseek-flash',
        defaultFreeChat: json['defaultFreeChat'] as bool? ?? false,
        concise: json['concise'] as bool? ?? true,
        fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1,
        contextTurns: json['contextTurns'] as int? ?? 12,
        maxTokens: json['maxTokens'] as int? ?? 4096,
        thinkingEnabled: json['thinkingEnabled'] as bool? ?? false,
        reasoningEffort: json['reasoningEffort'] as String? ?? 'high',
        searchEnabled: json['searchEnabled'] as bool? ?? false,
      );
}

class AssistantSearchSource {
  const AssistantSearchSource({
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String title;
  final String url;
  final String snippet;

  Map<String, Object?> toJson() => {
    'title': title,
    'url': url,
    'snippet': snippet,
  };

  factory AssistantSearchSource.fromJson(Map<String, Object?> json) =>
      AssistantSearchSource(
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        snippet: json['snippet'] as String? ?? '',
      );
}

class AssistantChatMessage {
  const AssistantChatMessage({
    required this.role,
    required this.content,
    this.completed = true,
    this.createdAt,
    this.reasoningContent = '',
    this.searchSources = const [],
    this.searchPerformed = false,
  });

  final String role;
  final String content;
  final bool completed;
  final DateTime? createdAt;
  final String reasoningContent;
  final List<AssistantSearchSource> searchSources;
  final bool searchPerformed;

  AssistantChatMessage copyWith({
    String? role,
    String? content,
    bool? completed,
    String? reasoningContent,
    List<AssistantSearchSource>? searchSources,
    bool? searchPerformed,
  }) => AssistantChatMessage(
    role: role ?? this.role,
    content: content ?? this.content,
    completed: completed ?? this.completed,
    createdAt: createdAt,
    reasoningContent: reasoningContent ?? this.reasoningContent,
    searchSources: searchSources ?? this.searchSources,
    searchPerformed: searchPerformed ?? this.searchPerformed,
  );

  Map<String, Object?> toJson() => {
    'role': role,
    'content': content,
    'completed': completed,
    'createdAt': createdAt?.toIso8601String(),
    'reasoningContent': reasoningContent,
    'searchSources': searchSources.map((source) => source.toJson()).toList(),
    'searchPerformed': searchPerformed,
  };

  factory AssistantChatMessage.fromJson(Map<String, Object?> json) =>
      AssistantChatMessage(
        role: json['role']! as String,
        content: json['content']! as String,
        completed: json['completed'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        reasoningContent: json['reasoningContent'] as String? ?? '',
        searchSources: (json['searchSources'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (source) => AssistantSearchSource.fromJson(
                source.cast<String, Object?>(),
              ),
            )
            .toList(growable: false),
        searchPerformed: json['searchPerformed'] as bool? ?? false,
      );
}

class AssistantChatSession {
  AssistantChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    required List<AssistantChatMessage> messages,
  }) : messages = List.unmodifiable(messages);

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<AssistantChatMessage> messages;

  AssistantChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    List<AssistantChatMessage>? messages,
  }) => AssistantChatSession(
    id: id,
    title: title ?? this.title,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory AssistantChatSession.fromJson(Map<String, Object?> json) =>
      AssistantChatSession(
        id: json['id']! as String,
        title: json['title']! as String,
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        messages: (json['messages'] as List? ?? const [])
            .map(
              (message) => AssistantChatMessage.fromJson(
                (message as Map).cast<String, Object?>(),
              ),
            )
            .toList(growable: false),
      );
}

class AssistantChatState {
  AssistantChatState({
    List<AssistantChatSession> sessions = const [],
    this.currentSessionId,
    List<AssistantChatMessage> messages = const [],
    this.isStreaming = false,
    this.isLoading = false,
    this.error,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.lastDuration,
  }) : sessions = List.unmodifiable(sessions),
       messages = List.unmodifiable(messages);

  final List<AssistantChatSession> sessions;
  final String? currentSessionId;
  final List<AssistantChatMessage> messages;
  final bool isStreaming;
  final bool isLoading;
  final String? error;
  final int inputTokens;
  final int outputTokens;
  final Duration? lastDuration;

  AssistantChatState copyWith({
    List<AssistantChatSession>? sessions,
    String? currentSessionId,
    bool clearCurrentSessionId = false,
    List<AssistantChatMessage>? messages,
    bool? isStreaming,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? inputTokens,
    int? outputTokens,
    Duration? lastDuration,
    bool clearLastDuration = false,
  }) => AssistantChatState(
    sessions: sessions ?? this.sessions,
    currentSessionId: clearCurrentSessionId
        ? null
        : (currentSessionId ?? this.currentSessionId),
    messages: messages ?? this.messages,
    isStreaming: isStreaming ?? this.isStreaming,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    lastDuration: clearLastDuration
        ? null
        : (lastDuration ?? this.lastDuration),
  );
}

String encodeAssistantChatHistory(
  List<AssistantChatSession> sessions,
  String? currentSessionId,
) => jsonEncode({
  'currentSessionId': currentSessionId,
  'sessions': sessions.map((session) => session.toJson()).toList(),
});
