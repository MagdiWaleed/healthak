enum ChatMessageKind { user, assistant, working, notice }

enum ChatMessageStatus { complete, streaming, error }

class ChatMessage {
  final String id;
  final ChatMessageKind kind;
  final ChatMessageStatus status;
  final String text;
  final String? toolName;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.status = ChatMessageStatus.complete,
    this.toolName,
  });

  ChatMessage copyWith({
    ChatMessageStatus? status,
    String? text,
  }) =>
      ChatMessage(
        id: id,
        kind: kind,
        status: status ?? this.status,
        text: text ?? this.text,
        toolName: toolName,
        createdAt: createdAt,
      );
}

class AgentToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AgentToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

sealed class AgentChunk {
  const AgentChunk();
}

final class AgentTextDelta extends AgentChunk {
  final String text;
  const AgentTextDelta(this.text);
}

final class AgentToolCallChunk extends AgentChunk {
  final AgentToolCall call;
  const AgentToolCallChunk(this.call);
}

final class AgentUsageChunk extends AgentChunk {
  final double? costUsd;
  const AgentUsageChunk({this.costUsd});
}

final class AgentDoneChunk extends AgentChunk {
  const AgentDoneChunk();
}

enum AgentFailureKind { offline, quota, unauthorized, invalidResponse, server }

class AgentException implements Exception {
  final AgentFailureKind kind;
  final String message;

  const AgentException(this.kind, this.message);

  @override
  String toString() => message;
}
