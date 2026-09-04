import 'agent_proposal.dart';

enum ChatMessageKind { user, assistant, working, notice, proposal, receipt }

enum ChatMessageStatus {
  complete,
  streaming,
  error,

  /// A [ChatMessageKind.proposal] card awaiting تأكيد/إلغاء.
  pendingConfirm,

  /// The user tapped إلغاء, or a newer proposal superseded this one.
  cancelled,

  /// A [ChatMessageKind.receipt] the user has undone.
  undone,
}

class ChatMessage {
  final String id;
  final ChatMessageKind kind;
  final ChatMessageStatus status;
  final String text;
  final String? toolName;
  final DateTime createdAt;

  /// Set only for [ChatMessageKind.proposal]. Never persisted -- a pending
  /// card cannot be confirmed after the process restarts, so it is dropped
  /// on restore rather than shown non-functional.
  final Proposal? proposal;

  /// Set only for [ChatMessageKind.receipt]. Not persisted either; a
  /// restored receipt still shows its summary text, just without a working
  /// undo chip.
  final AgentReceipt? receipt;

  const ChatMessage({
    required this.id,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.status = ChatMessageStatus.complete,
    this.toolName,
    this.proposal,
    this.receipt,
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
        proposal: proposal,
        receipt: receipt,
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
