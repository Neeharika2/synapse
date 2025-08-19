class Todo {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final String status; // 'pending', 'in_progress', 'completed'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String? assignedTo;
  final String? assignedToName;
  final DateTime? dueDate;
  final DateTime createdAt;

  Todo({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.assignedToName,
    this.dueDate,
    required this.createdAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] ?? '',
      projectId: json['project_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'medium',
      assignedTo: json['assigned_to'],
      assignedToName: json['assigned_to_name'],
      dueDate:
          json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
