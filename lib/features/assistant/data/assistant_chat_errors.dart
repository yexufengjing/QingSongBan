class AssistantChatException implements Exception {
  const AssistantChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AssistantChatCancelled implements Exception {
  const AssistantChatCancelled();
}
