class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.category,
    required this.shortDescription,
    this.longDescription,
    this.icon,
    this.startingPrice,
    this.priceUnit,
    this.isActive = true,
    this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String slug;
  final String category;
  final String shortDescription;
  final String? longDescription;
  final String? icon;
  final double? startingPrice;
  final String? priceUnit;
  final bool isActive;
  final int? sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toRow() => {
        'title': title,
        'slug': slug,
        'category': category,
        'shortDescription': shortDescription,
        'longDescription': ?longDescription,
        'icon': ?icon,
        'startingPrice': ?startingPrice,
        'priceUnit': ?priceUnit,
        'isActive': isActive,
        'sortOrder': ?sortOrder,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ServiceItem.fromRow(String id, Map<String, dynamic> data) {
    return ServiceItem(
      id: id,
      title: data['title']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      shortDescription: data['shortDescription']?.toString() ?? '',
      longDescription: data['longDescription']?.toString(),
      icon: data['icon']?.toString(),
      startingPrice: (data['startingPrice'] as num?)?.toDouble(),
      priceUnit: data['priceUnit']?.toString(),
      isActive: data['isActive'] != false,
      sortOrder: (data['sortOrder'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
