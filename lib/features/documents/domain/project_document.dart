enum DocumentCategory {
  drawing('drawing', 'Drawing'),
  contract('contract', 'Contract'),
  report('report', 'Report'),
  permit('permit', 'Permit'),
  photo('photo', 'Photo'),
  other('other', 'Other');

  const DocumentCategory(this.value, this.label);
  final String value;
  final String label;

  static DocumentCategory fromString(String raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => DocumentCategory.other,
      );
}

class ProjectDocument {
  const ProjectDocument({
    required this.id,
    required this.projectId,
    required this.title,
    required this.category,
    required this.fileId,
    this.version = 1,
    this.parentDocumentId,
    required this.uploadedBy,
    this.isClientVisible = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final DocumentCategory category;
  final String fileId;
  final int version;
  final String? parentDocumentId;
  final String uploadedBy;
  final bool isClientVisible;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'title': title,
        'category': category.value,
        'fileId': fileId,
        'version': version,
        'parentDocumentId': ?parentDocumentId,
        'uploadedBy': uploadedBy,
        'isClientVisible': isClientVisible,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory ProjectDocument.fromJson(Map<String, dynamic> data) {
    return ProjectDocument(
      id: data['id']?.toString() ?? '',
      projectId: data['projectId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      category: DocumentCategory.fromString(data['category']?.toString() ?? 'other'),
      fileId: data['fileId']?.toString() ?? '',
      version: (data['version'] as num?)?.toInt() ?? 1,
      parentDocumentId: data['parentDocumentId']?.toString(),
      uploadedBy: data['uploadedBy']?.toString() ?? '',
      isClientVisible: data['isClientVisible'] != false,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
