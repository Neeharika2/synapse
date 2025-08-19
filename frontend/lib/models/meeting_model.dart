class ProjectMeeting {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final DateTime meetingDate;
  final String meetingTime;
  final int duration; // in minutes
  final String? platform; // zoom, meet, teams, etc.
  final String? meetingUrl;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;

  ProjectMeeting({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.meetingDate,
    required this.meetingTime,
    required this.duration,
    this.platform,
    this.meetingUrl,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
  });

  factory ProjectMeeting.fromJson(Map<String, dynamic> json) {
    return ProjectMeeting(
      id: json['id'] ?? '',
      projectId: json['project_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      meetingDate: json['meeting_date'] != null
          ? DateTime.parse(json['meeting_date'])
          : DateTime.now(),
      meetingTime: json['meeting_time'] ?? '00:00',
      duration: json['duration'] ?? 60,
      platform: json['platform'],
      meetingUrl: json['meeting_url'],
      createdBy: json['created_by'] ?? '',
      createdByName: json['created_by_name'],
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
      'meeting_date': meetingDate.toIso8601String(),
      'meeting_time': meetingTime,
      'duration': duration,
      'platform': platform,
      'meeting_url': meetingUrl,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
