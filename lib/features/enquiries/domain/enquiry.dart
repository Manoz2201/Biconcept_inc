class Enquiry {
  const Enquiry({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.serviceId,
    required this.message,
    required this.status,
    this.source,
    this.assignedTo,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? serviceId;
  final String message;
  final EnquiryStatus status;
  final String? source;
  final String? assignedTo;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toRow() => {
        'name': name,
        'email': email,
        'phone': ?phone,
        'serviceId': ?serviceId,
        'message': message,
        'status': status.value,
        'source': ?source,
        'assignedTo': ?assignedTo,
        'notes': ?notes,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Enquiry.fromRow(String id, Map<String, dynamic> data) {
    return Enquiry(
      id: id,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString(),
      serviceId: data['serviceId']?.toString(),
      message: data['message']?.toString() ?? '',
      status: EnquiryStatus.fromString(data['status']?.toString() ?? 'new'),
      source: data['source']?.toString(),
      assignedTo: data['assignedTo']?.toString(),
      notes: data['notes']?.toString(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}

enum EnquiryStatus {
  newLead('new', 'New'),
  contacted('contacted', 'Contacted'),
  qualified('qualified', 'Qualified'),
  converted('converted', 'Converted'),
  closed('closed', 'Closed');

  const EnquiryStatus(this.value, this.label);

  final String value;
  final String label;

  static EnquiryStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw,
        orElse: () => EnquiryStatus.newLead,
      );
}
