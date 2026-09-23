const kVendorCategories = [
  'civil',
  'electrical',
  'plumbing',
  'interior',
  'hvac',
  'carpentry',
  'painting',
  'structural',
  'other',
];

String vendorCategoryLabel(String value) => switch (value) {
      'civil' => 'Civil',
      'electrical' => 'Electrical',
      'plumbing' => 'Plumbing',
      'interior' => 'Interior',
      'hvac' => 'HVAC',
      'carpentry' => 'Carpentry',
      'painting' => 'Painting',
      'structural' => 'Structural',
      _ => 'Other',
    };

class Vendor {
  const Vendor({
    required this.id,
    this.userId,
    required this.companyName,
    required this.contactPerson,
    required this.email,
    required this.phone,
    this.gstin,
    this.panNumber,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.bankName,
    this.bankAccountNumber,
    this.ifscCode,
    this.categories = const [],
    this.rating = 0,
    this.totalRatings = 0,
    this.isActive = true,
    this.isVerified = false,
    this.kycDocuments = const [],
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? userId;
  final String companyName;
  final String contactPerson;
  final String email;
  final String phone;
  final String? gstin;
  final String? panNumber;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String? bankName;
  final String? bankAccountNumber;
  final String? ifscCode;
  final List<String> categories;
  final double rating;
  final int totalRatings;
  final bool isActive;
  final bool isVerified;
  final List<String> kycDocuments;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Vendor.fromRow(String id, Map<String, dynamic> data) {
    List<String> strings(Object? raw) =>
        raw is List ? raw.map((item) => item.toString()).toList() : const [];
    return Vendor(
      id: id,
      userId: data['userId']?.toString(),
      companyName: data['companyName']?.toString() ?? '',
      contactPerson: data['contactPerson']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      gstin: data['gstin']?.toString(),
      panNumber: data['panNumber']?.toString(),
      address: data['address']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      state: data['state']?.toString() ?? '',
      pincode: data['pincode']?.toString() ?? '',
      bankName: data['bankName']?.toString(),
      bankAccountNumber: data['bankAccountNumber']?.toString(),
      ifscCode: data['ifscCode']?.toString(),
      categories: strings(data['categories']),
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (data['totalRatings'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] != false,
      isVerified: data['isVerified'] == true,
      kycDocuments: strings(data['kycDocuments']),
      notes: data['notes']?.toString(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
