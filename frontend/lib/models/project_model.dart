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
      try {
        members = (json['members'] as List)
            .map((memberJson) => User.fromJson(memberJson))
            .toList();
      } catch (e) {
        print('Error parsing members: $e');
        members = [];
      }
    }

    // Process required skills
    List<String> skills = [];
    if (json['required_skills'] != null) {
      try {
        if (json['required_skills'] is List) {
          skills = (json['required_skills'] as List)
              .map((skill) => skill.toString())
              .toList();
        } else if (json['required_skills'] is String) {
          final parsed = jsonDecode(json['required_skills']);
          if (parsed is List) {
            skills = parsed.map((skill) => skill.toString()).toList();
          }
        }
      } catch (e) {
        print('Error parsing required skills: $e');
        skills = [];
      }
    }

    // Process pending requests
    List<JoinRequest> pendingRequests = [];
    if (json['pending_requests'] != null && json['pending_requests'] is List) {
      try {
        pendingRequests = [];
        for (var requestJson in json['pending_requests']) {
          try {
            pendingRequests.add(JoinRequest.fromJson(requestJson));
          } catch (e) {
            print('Error parsing individual join request: $e');
            print('Problematic request data: $requestJson');
          }
        }
      } catch (e) {
        print('Error parsing pending requests: $e');
        print('Pending requests data: ${json['pending_requests']}');
        pendingRequests = [];
      }
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
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
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
    try {
      return User(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? 'Unknown User',
        email: json['email'] ?? '',
        avatarUrl: json['avatar_url'],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
            : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing User: $e');
      return User.empty();
    }
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
  final String projectId; // Added project ID field
  final User user;
  final String? message;
  final DateTime requestedAt;

  JoinRequest({
    required this.id,
    required this.projectId, // Required project ID
    required this.user,
    this.message,
    required this.requestedAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    try {
      // Handle different user data formats from backend
      User user;
      if (json.containsKey('user')) {
        user = User.fromJson(json['user'] ?? {});
      } else if (json.containsKey('user_id') && json.containsKey('user_name')) {
        user = User(
          id: json['user_id']?.toString() ?? '',
          name: json['user_name'] ?? 'Unknown User',
          email: json['user_email'] ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } else {
        user = User.empty();
      }

      // Handle different date formats
      DateTime requestedAt = DateTime.now();
      if (json['requested_at'] != null) {
        requestedAt = DateTime.tryParse(json['requested_at']) ?? DateTime.now();
      } else if (json['created_at'] != null) {
        requestedAt = DateTime.tryParse(json['created_at']) ?? DateTime.now();
      }

      return JoinRequest(
        id: json['id']?.toString() ?? '',
        projectId: json['project_id']?.toString() ?? '',
        user: user,
        message: json['message'],
        requestedAt: requestedAt,
      );
    } catch (e) {
      print('Error parsing JoinRequest: $e');
      return JoinRequest(
        id: json['id']?.toString() ?? '',
        projectId: json['project_id']?.toString() ?? '',
        user: User.empty(),
        message: json['message'],
        requestedAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'user': user.toJson(),
      'message': message,
      'requested_at': requestedAt.toIso8601String(),
    };
  }
}
