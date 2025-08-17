import 'dart:convert';

class Project {
  final String id;
  final String title;
  final String description;
  final String status;
  final List<String> requiredSkills;
  final int maxMembers;
  final int currentMembers;
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User creator;
  final List<User> members;
  final bool canLeave;
  final List<JoinRequest> pendingRequests; // Added this field

  Project({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.requiredSkills,
    required this.maxMembers,
    required this.currentMembers,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    required this.creator,
    required this.members,
    this.canLeave = false,
    this.pendingRequests = const [], // Default empty list
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    // Process creator data
    User creator;
    if (json.containsKey('creator_id') && json.containsKey('creator_name')) {
      creator = User(
        id: json['creator_id']?.toString() ?? '',
        name: json['creator_name'] ?? 'Unknown Creator',
        email: json['creator_email'] ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      creator = User.empty();
    }

    // Process members data
    List<User> members = [];
    if (json['members'] != null && json['members'] is List) {
      members =
          (json['members'] as List)
              .map((memberJson) => User.fromJson(memberJson))
              .toList();
    }

    // Process required skills
    List<String> skills = [];
    if (json['required_skills'] != null) {
      if (json['required_skills'] is List) {
        skills =
            (json['required_skills'] as List)
                .map((skill) => skill.toString())
                .toList();
      } else if (json['required_skills'] is String) {
        try {
          final parsed = jsonDecode(json['required_skills']);
          if (parsed is List) {
            skills = parsed.map((skill) => skill.toString()).toList();
          }
        } catch (_) {
          // If parsing fails, leave as empty list
        }
      }
    }

    // Process pending requests
    List<JoinRequest> pendingRequests = [];
    if (json['pending_requests'] != null && json['pending_requests'] is List) {
      pendingRequests = (json['pending_requests'] as List)
          .map((requestJson) => JoinRequest.fromJson(requestJson))
          .toList();
    }

    return Project(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Untitled Project',
      description: json['description'] ?? '',
      status: json['status'] ?? 'open',
      requiredSkills: skills,
      maxMembers: json['max_members'] ?? 5,
      currentMembers: json['current_members'] ?? 0,
      visibility: json['visibility'] ?? 'public',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
      creator: creator,
      members: members,
      canLeave: json['can_leave'] ?? false,
      pendingRequests: pendingRequests,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'required_skills': requiredSkills,
      'max_members': maxMembers,
      'current_members': currentMembers,
      'visibility': visibility,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'creator': creator.toJson(),
      'members': members.map((member) => member.toJson()).toList(),
      'can_leave': canLeave,
      'pending_requests':
          pendingRequests.map((request) => request.toJson()).toList(),
    };
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown User',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static User empty() {
    return User(
      id: '',
      name: 'Unknown User',
      email: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class JoinRequest {
  final String id;
  final User user;
  final String? message;
  final DateTime requestedAt;

  JoinRequest({
    required this.id,
    required this.user,
    this.message,
    required this.requestedAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
      message: json['message'],
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'message': message,
      'requested_at': requestedAt.toIso8601String(),
    };
  }
}
