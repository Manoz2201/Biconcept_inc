import 'package:package_info_plus/package_info_plus.dart';

const defaultUpdateRepo = String.fromEnvironment(
  'UPDATE_REPO',
  defaultValue: 'Manoz2201/Biconcept_inc',
);

const appGitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'local');
const appChannel = String.fromEnvironment('APP_CHANNEL', defaultValue: 'dev');

class AppBuildInfo {
  const AppBuildInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
    this.gitSha = appGitSha,
    this.channel = appChannel,
  });

  final String appName;
  final String version;
  final int buildNumber;
  final String gitSha;
  final String channel;

  String get display => '$version+$buildNumber';

  String get shortSha {
    final value = gitSha.trim();
    if (value.isEmpty || value == 'local') return 'local';
    return value.length <= 7 ? value : value.substring(0, 7);
  }

  static Future<AppBuildInfo> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppBuildInfo(
        appName: info.appName.trim().isEmpty ? 'BiConcept' : info.appName.trim(),
        version: info.version.trim().isEmpty ? '0.0.0' : info.version.trim(),
        buildNumber: int.tryParse(info.buildNumber.trim()) ?? 0,
      );
    } catch (_) {
      return const AppBuildInfo(appName: 'BiConcept', version: '0.0.0', buildNumber: 0);
    }
  }
}

String normalizeVersion(String raw) {
  var value = raw.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  final plus = value.indexOf('+');
  if (plus >= 0) value = value.substring(0, plus);
  final dash = value.indexOf('-');
  if (dash >= 0) value = value.substring(0, dash);
  return value.trim();
}

int compareVersions(String left, String right) {
  final a = _versionParts(left);
  final b = _versionParts(right);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final av = i < a.length ? a[i] : 0;
    final bv = i < b.length ? b[i] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

bool isRemoteNewer({
  required String currentVersion,
  required int currentBuild,
  required String remoteVersion,
  required int remoteBuild,
}) {
  final cmp = compareVersions(currentVersion, remoteVersion);
  if (cmp != 0) return cmp < 0;
  if (remoteBuild <= 0) return false;
  return remoteBuild > currentBuild;
}

List<int> _versionParts(String raw) {
  final core = normalizeVersion(raw);
  if (core.isEmpty) return const [0];
  return [
    for (final part in core.split('.')) int.tryParse(part) ?? 0,
  ];
}
