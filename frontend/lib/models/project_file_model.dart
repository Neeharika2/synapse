class ProjectFile {
  final String id;
  final String projectId;
  final String fileName;
  final String? fileType;
  final int? fileSize;
  final String fileUrl;
  final String uploadedBy;
  final String? uploadedByName;
  final DateTime uploadedAt;

  ProjectFile({
    required this.id,
    required this.projectId,
    required this.fileName,
    this.fileType,
    this.fileSize,
    required this.fileUrl,
    required this.uploadedBy,
    this.uploadedByName,
    required this.uploadedAt,
  });

  factory ProjectFile.fromJson(Map<String, dynamic> json) {
    return ProjectFile(
      id: json['id'] ?? '',
      projectId: json['project_id'] ?? '',
      fileName: json['file_name'] ?? '',
      fileType: json['file_type'],
      fileSize: json['file_size'],
      fileUrl: json['file_url'] ?? '',
      uploadedBy: json['uploaded_by'] ?? '',
      uploadedByName: json['uploaded_by_name'],
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'file_url': fileUrl,
      'uploaded_by': uploadedBy,
      'uploaded_by_name': uploadedByName,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}
