class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    required this.role,
    this.bio,
    this.photoId,
    this.email,
    this.linkedin,
    this.sortOrder,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String role;
  final String? bio;
  final String? photoId;
  final String? email;
  final String? linkedin;
  final int? sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toRow() => {
        'name': name,
        'role': role,
        'bio': ?bio,
        'photoId': ?photoId,
        'email': ?email,
        'linkedin': ?linkedin,
        'sortOrder': ?sortOrder,
        'isActive': isActive,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory TeamMember.fromRow(String id, Map<String, dynamic> data) {
    return TeamMember(
      id: id,
      name: data['name']?.toString() ?? '',
      role: data['role']?.toString() ?? '',
      bio: data['bio']?.toString(),
      photoId: data['photoId']?.toString(),
      email: data['email']?.toString(),
      linkedin: data['linkedin']?.toString(),
      sortOrder: (data['sortOrder'] as num?)?.toInt(),
      isActive: data['isActive'] != false,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
