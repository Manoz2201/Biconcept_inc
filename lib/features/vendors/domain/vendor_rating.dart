class VendorRating {
  const VendorRating({
    required this.id,
    required this.vendorId,
    required this.projectId,
    required this.ratedBy,
    required this.qualityScore,
    required this.timelinessScore,
    required this.communicationScore,
    required this.costScore,
    required this.overallScore,
    this.comments,
    this.createdAt,
  });

  final String id;
  final String vendorId;
  final String projectId;
  final String ratedBy;
  final int qualityScore;
  final int timelinessScore;
  final int communicationScore;
  final int costScore;
  final double overallScore;
  final String? comments;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendorId': vendorId,
        'projectId': projectId,
        'ratedBy': ratedBy,
        'qualityScore': qualityScore,
        'timelinessScore': timelinessScore,
        'communicationScore': communicationScore,
        'costScore': costScore,
        'overallScore': overallScore,
        'comments': ?comments,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };

  factory VendorRating.fromJson(Map<String, dynamic> data) => VendorRating(
        id: data['id']?.toString() ?? '',
        vendorId: data['vendorId']?.toString() ?? '',
        projectId: data['projectId']?.toString() ?? '',
        ratedBy: data['ratedBy']?.toString() ?? '',
        qualityScore: (data['qualityScore'] as num?)?.toInt() ?? 0,
        timelinessScore: (data['timelinessScore'] as num?)?.toInt() ?? 0,
        communicationScore: (data['communicationScore'] as num?)?.toInt() ?? 0,
        costScore: (data['costScore'] as num?)?.toInt() ?? 0,
        overallScore: (data['overallScore'] as num?)?.toDouble() ?? 0,
        comments: data['comments']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );
}

double ratingAverage(Iterable<VendorRating> ratings) {
  if (ratings.isEmpty) return 0;
  final total = ratings.fold<double>(0, (sum, item) => sum + item.overallScore);
  return double.parse((total / ratings.length).toStringAsFixed(2));
}

double overallFromScores({
  required int quality,
  required int timeliness,
  required int communication,
  required int cost,
}) {
  return ((quality + timeliness + communication + cost) / 4).toDouble();
}
