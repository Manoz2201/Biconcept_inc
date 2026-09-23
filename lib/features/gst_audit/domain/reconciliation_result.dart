class ReconciliationResult {
  const ReconciliationResult({
    required this.exactMatches,
    required this.suggestedMatches,
    required this.mismatched,
    required this.missingIn2b,
    required this.missingInBooks,
    required this.totalProcessed,
  });

  final int exactMatches;
  final int suggestedMatches;
  final int mismatched;
  final int missingIn2b;
  final int missingInBooks;
  final int totalProcessed;

  double get matchPercentage {
    if (totalProcessed == 0) return 0;
    return ((exactMatches + suggestedMatches) / totalProcessed) * 100;
  }

  Map<String, dynamic> toJson() => {
        'exactMatches': exactMatches,
        'suggestedMatches': suggestedMatches,
        'mismatched': mismatched,
        'missingIn2b': missingIn2b,
        'missingInBooks': missingInBooks,
        'totalProcessed': totalProcessed,
        'matchPercentage': matchPercentage,
      };
}
