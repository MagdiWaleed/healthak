/// One conversation thread. Metadata only -- its messages live separately
/// in [AgentConversationStore], keyed by [id].
class ChatSession {
  final String id;

  /// Null until the first exchange completes and a title is generated
  /// (AI-generated from the first user message, falling back to a plain
  /// truncation if generation fails or is unavailable offline).
  final String? title;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title,
  });

  ChatSession copyWith({String? title, DateTime? updatedAt}) => ChatSession(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        title: title ?? this.title,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String? ?? '',
        title: json['title'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
