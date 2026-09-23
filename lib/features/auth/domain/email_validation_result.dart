class EmailValidationResult {
  const EmailValidationResult({
    required this.isValid,
    this.isDisposable = false,
    this.isFreeProvider = false,
    this.mxFound = false,
    this.suggestion,
    this.reason,
  });

  final bool isValid;
  final bool isDisposable;
  final bool isFreeProvider;
  final bool mxFound;
  final String? suggestion;
  final String? reason;

  factory EmailValidationResult.fromJson(Map<String, dynamic> json) {
    return EmailValidationResult(
      isValid: json['isValid'] == true,
      isDisposable: json['isDisposable'] == true,
      isFreeProvider: json['isFreeProvider'] == true,
      mxFound: json['mxFound'] == true,
      suggestion: json['suggestion']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}
