class DeepLinkPayload {
  const DeepLinkPayload({
    required this.kind,
    this.userId,
    this.secret,
    this.membershipId,
    this.teamId,
    this.email,
  });

  final DeepLinkKind kind;
  final String? userId;
  final String? secret;
  final String? membershipId;
  final String? teamId;
  final String? email;

  bool get isValid =>
      (userId?.isNotEmpty ?? false) && (secret?.isNotEmpty ?? false);

  static DeepLinkPayload? tryParse(Uri uri) {
    final kind = DeepLinkKind.fromUri(uri);
    if (kind == null) return null;
    final userId = uri.queryParameters['userId'] ?? uri.queryParameters['user_id'];
    final secret = uri.queryParameters['secret'];
    if (userId == null || userId.isEmpty || secret == null || secret.isEmpty) {
      return DeepLinkPayload(kind: kind, userId: userId, secret: secret);
    }
    return DeepLinkPayload(
      kind: kind,
      userId: userId,
      secret: secret,
      membershipId: uri.queryParameters['membershipId'] ?? uri.queryParameters['membership_id'],
      teamId: uri.queryParameters['teamId'] ?? uri.queryParameters['team_id'],
      email: uri.queryParameters['email'],
    );
  }
}

enum DeepLinkKind {
  verify,
  invite,
  resetPassword;

  static DeepLinkKind? fromUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last.toLowerCase();
    final token = switch (host) {
      'verify' || 'invite' || 'reset-password' || 'resetpassword' => host,
      _ => last.isNotEmpty ? last : host,
    };
    return switch (token) {
      'verify' || 'verify-email' => DeepLinkKind.verify,
      'invite' || 'register' => DeepLinkKind.invite,
      'reset-password' || 'resetpassword' => DeepLinkKind.resetPassword,
      _ => null,
    };
  }
}
