class VendorRate {
  const VendorRate({
    required this.id,
    required this.vendorId,
    required this.category,
    required this.itemName,
    this.description,
    required this.unit,
    required this.rate,
    this.currency = 'INR',
    this.minimumQuantity,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String vendorId;
  final String category;
  final String itemName;
  final String? description;
  final String unit;
  final double rate;
  final String currency;
  final double? minimumQuantity;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendorId': vendorId,
        'category': category,
        'itemName': itemName,
        'description': ?description,
        'unit': unit,
        'rate': rate,
        'currency': currency,
        'minimumQuantity': ?minimumQuantity,
        'isActive': isActive,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory VendorRate.fromJson(Map<String, dynamic> data) => VendorRate(
        id: data['id']?.toString() ?? '',
        vendorId: data['vendorId']?.toString() ?? '',
        category: data['category']?.toString() ?? 'other',
        itemName: data['itemName']?.toString() ?? '',
        description: data['description']?.toString(),
        unit: data['unit']?.toString() ?? 'nos',
        rate: (data['rate'] as num?)?.toDouble() ?? 0,
        currency: data['currency']?.toString() ?? 'INR',
        minimumQuantity: (data['minimumQuantity'] as num?)?.toDouble(),
        isActive: data['isActive'] != false,
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}
