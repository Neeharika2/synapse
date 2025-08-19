class ChatMessage {
  final String id;
  final String projectId;
  final String userId;
  final String? userName;
  final String message;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.projectId,
    required this.userId,
    this.userName,
    required this.message,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      projectId: json['project_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'],
      message: json['message'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'user_id': userId,
      'user_name': userName,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
