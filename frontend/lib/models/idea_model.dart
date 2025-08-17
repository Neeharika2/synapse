import 'user_model.dart';

class Idea {
  final String id;
  final String title;
  final String description;
  final User author;
  final List<String> tags;
  final int likes;
  final int comments;
  final List<User> likedBy;
  final bool isLiked;
  final DateTime createdAt;
  final DateTime updatedAt;

  Idea({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.likedBy,
    required this.isLiked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Idea.fromJson(Map<String, dynamic> json) {
    return Idea(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      author: json['author'] != null ? User.fromJson(json['author']) : UserExtension.empty(),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      likedBy: json['likedBy'] != null 
          ? (json['likedBy'] as List).map((user) => User.fromJson(user)).toList()
          : [],
      isLiked: json['isLiked'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'author': author.toJson(),
      'tags': tags,
      'likes': likes,
      'comments': comments,
      'likedBy': likedBy.map((user) => user.toJson()).toList(),
      'isLiked': isLiked,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

extension UserExtension on User {
  static User empty() {
    return User(
      id: '',
      name: 'Unknown',
      email: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}