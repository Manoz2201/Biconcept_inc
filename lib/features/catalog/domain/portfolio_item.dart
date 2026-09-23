class PortfolioItem {
  const PortfolioItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.projectType,
    this.location,
    this.area,
    this.year,
    this.description,
    required this.coverImageId,
    this.galleryImageIds = const [],
    this.testimonial,
    this.clientName,
    this.isFeatured = false,
    this.isActive = true,
    this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String slug;
  final String projectType;
  final String? location;
  final String? area;
  final int? year;
  final String? description;
  final String coverImageId;
  final List<String> galleryImageIds;
  final String? testimonial;
  final String? clientName;
  final bool isFeatured;
  final bool isActive;
  final int? sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toRow() => {
        'title': title,
        'slug': slug,
        'projectType': projectType,
        'location': ?location,
        'area': ?area,
        'year': ?year,
        'description': ?description,
        'coverImageId': coverImageId,
        'galleryImageIds': galleryImageIds,
        'testimonial': ?testimonial,
        'clientName': ?clientName,
        'isFeatured': isFeatured,
        'isActive': isActive,
        'sortOrder': ?sortOrder,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory PortfolioItem.fromRow(String id, Map<String, dynamic> data) {
    final gallery = data['galleryImageIds'];
    return PortfolioItem(
      id: id,
      title: data['title']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      projectType: data['projectType']?.toString() ?? '',
      location: data['location']?.toString(),
      area: data['area']?.toString(),
      year: (data['year'] as num?)?.toInt(),
      description: data['description']?.toString(),
      coverImageId: data['coverImageId']?.toString() ?? '',
      galleryImageIds: gallery is List ? gallery.map((e) => e.toString()).toList() : const [],
      testimonial: data['testimonial']?.toString(),
      clientName: data['clientName']?.toString(),
      isFeatured: data['isFeatured'] == true,
      isActive: data['isActive'] != false,
      sortOrder: (data['sortOrder'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
