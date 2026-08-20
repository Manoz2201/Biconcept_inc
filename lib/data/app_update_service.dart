import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_version.dart';
import 'github_sync.dart';

class AppReleaseAsset {
  const AppReleaseAsset({
    required this.name,
    required this.apiUrl,
    required this.browserUrl,
    this.size = 0,
  });

  final String name;
  final String apiUrl;
  final String browserUrl;
  final int size;

  String get downloadUrl => apiUrl.isNotEmpty ? apiUrl : browserUrl;
}

class AppRelease {
  const AppRelease({
    required this.version,
    required this.build,
    required this.tag,
    required this.htmlUrl,
    this.notes = '',
    this.channel = 'release',
    this.gitSha = '',
    this.android,
    this.windows,
  });

  final String version;
  final int build;
  final String tag;
  final String htmlUrl;
  final String notes;
  final String channel;
  final String gitSha;
  final AppReleaseAsset? android;
  final AppReleaseAsset? windows;

  String get display => build > 0 ? '$version+$build' : version;

  AppReleaseAsset? assetForPlatform() {
    if (Platform.isAndroid) return android;
    if (Platform.isWindows) return windows;
    return null;
  }
}

class AppUpdateCheck {
  const AppUpdateCheck({
    required this.current,
    this.latest,
    this.error,
  });

  final AppBuildInfo current;
  final AppRelease? latest;
  final String? error;

  bool get available {
    final remote = latest;
    if (remote == null) return false;
    return isRemoteNewer(
      currentVersion: current.version,
      currentBuild: current.buildNumber,
      remoteVersion: remote.version,
      remoteBuild: remote.build,
    );
  }
}

class AppUpdateService {
  AppUpdateService({
    http.Client? httpClient,
    this.repo = defaultUpdateRepo,
  }) : _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  final http.Client _http;
  final bool _ownsClient;
  final String repo;

  void close() {
    if (_ownsClient) _http.close();
  }

  Future<AppUpdateCheck> check({
    required AppBuildInfo current,
    String? token,
  }) async {
    final parsed = parseGitHubRepo(repo);
    if (parsed == null) {
      return AppUpdateCheck(current: current, error: 'Update repo is not configured.');
    }
    try {
      final latest = await _fetchLatest(parsed, token);
      if (latest == null) {
        return AppUpdateCheck(
          current: current,
          error: 'No GitHub Release yet. Tag vX.Y.Z and run the Release workflow.',
        );
      }
      return AppUpdateCheck(current: current, latest: latest);
    } on FormatException catch (error) {
      return AppUpdateCheck(current: current, error: error.message);
    } on SocketException {
      return AppUpdateCheck(current: current, error: 'No network. Connect and try again.');
    } catch (error) {
      return AppUpdateCheck(current: current, error: error.toString());
    }
  }

  Future<File> download({
    required AppRelease release,
    String? token,
    void Function(double? progress)? onProgress,
  }) async {
    final asset = release.assetForPlatform();
    if (asset == null || asset.downloadUrl.isEmpty) {
      throw const FormatException('This release has no installer for this device.');
    }
    final dir = await getTemporaryDirectory();
    final ext = Platform.isAndroid ? 'apk' : 'zip';
    final file = File('${dir.path}${Platform.pathSeparator}biconcept-update.$ext');
    if (file.existsSync()) {
      await file.delete();
    }

    onProgress?.call(-1);
    final request = http.Request('GET', Uri.parse(asset.downloadUrl));
    request.headers.addAll(_headers(token, download: true));
    final response = await _http.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'Could not download the update (HTTP ${response.statusCode}).',
      );
    }

    final total = response.contentLength ?? asset.size;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress?.call((received / total).clamp(0, 1));
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    onProgress?.call(1);
    return file;
  }

  Future<Directory> extractWindowsZip(File zip) async {
    final dest = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}biconcept-update-extract',
    );
    if (dest.existsSync()) {
      await dest.delete(recursive: true);
    }
    await dest.create(recursive: true);
    final quotedZip = zip.path.replaceAll("'", "''");
    final quotedDest = dest.path.replaceAll("'", "''");
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "Expand-Archive -LiteralPath '$quotedZip' -DestinationPath '$quotedDest' -Force",
    ]);
    if (result.exitCode != 0) {
      final detail = (result.stderr.toString().trim().isEmpty
              ? result.stdout.toString()
              : result.stderr.toString())
          .trim();
      throw FormatException(
        detail.isEmpty ? 'Could not unpack the Windows update.' : detail,
      );
    }
    return dest;
  }

  Future<File> findWindowsExe(Directory root) async {
    final direct = File('${root.path}${Platform.pathSeparator}biconcept.exe');
    if (direct.existsSync()) return direct;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('biconcept.exe')) {
        return entity;
      }
    }
    throw const FormatException('The Windows update zip did not contain biconcept.exe.');
  }

  Future<void> applyWindowsUpdate(Directory extracted) async {
    final exe = await findWindowsExe(extracted);
    final source = exe.parent.path;
    final dest = File(Platform.resolvedExecutable).parent.path;
    final script = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}biconcept-apply-update.cmd',
    );
    await script.writeAsString(
      '@echo off\r\n'
      'timeout /t 2 /nobreak >nul\r\n'
      'robocopy "$source" "$dest" /E /IS /IT /NFL /NDL /NJH /NJS\r\n'
      'if %ERRORLEVEL% GEQ 8 exit /b 1\r\n'
      'start "" "$dest\\biconcept.exe"\r\n'
      'del "%~f0"\r\n',
    );
    await Process.start(
      'cmd.exe',
      ['/c', script.path],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  Future<AppRelease?> _fetchLatest(GitHubRepoRef parsed, String? token) async {
    final uri = Uri.https('api.github.com', '/repos/${parsed.slug}/releases/latest');
    final response = await _http.get(uri, headers: _headers(token));
    if (response.statusCode == 401) {
      throw const FormatException(
        'GitHub rejected the request. If the repo is private, save a token with Contents read.',
      );
    }
    if (response.statusCode == 404) {
      throw FormatException(
        'No GitHub Release on ${parsed.slug}. Tag vX.Y.Z to publish one, or save a GitHub token if the repo is private.',
      );
    }
    _throwIfFailed(response, 'Could not check GitHub Releases');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected GitHub Releases response.');
    }
    return _releaseFromGithub(Map<String, dynamic>.from(decoded), token);
  }

  Future<AppRelease> _releaseFromGithub(Map<String, dynamic> json, String? token) async {
    final tag = json['tag_name']?.toString() ?? '';
    final htmlUrl = json['html_url']?.toString() ?? '';
    final notes = (json['body']?.toString() ?? '').trim();
    final assets = <AppReleaseAsset>[
      for (final item in json['assets'] as List? ?? const [])
        if (item is Map) _assetFromGithub(Map<String, dynamic>.from(item)),
    ];

    var version = normalizeVersion(tag);
    var build = 0;
    var channel = 'release';
    var gitSha = '';
    var resolvedNotes = notes;

    AppReleaseAsset? manifest;
    for (final asset in assets) {
      if (asset.name.toLowerCase() == 'latest.json') {
        manifest = asset;
        break;
      }
    }
    if (manifest != null && manifest.downloadUrl.isNotEmpty) {
      try {
        final overlay = await _fetchManifest(manifest, token);
        version = normalizeVersion(overlay['version']?.toString() ?? version);
        build = int.tryParse(overlay['build']?.toString() ?? '') ?? build;
        channel = overlay['channel']?.toString() ?? channel;
        gitSha = overlay['gitSha']?.toString() ?? gitSha;
        final extra = overlay['notes']?.toString().trim() ?? '';
        if (extra.isNotEmpty) resolvedNotes = extra;
      } catch (_) {
        // GitHub asset list is enough when latest.json cannot be read.
      }
    }

    return AppRelease(
      version: version.isEmpty ? '0.0.0' : version,
      build: build,
      tag: tag.isEmpty ? 'v$version' : tag,
      htmlUrl: htmlUrl,
      notes: resolvedNotes,
      channel: channel,
      gitSha: gitSha,
      android: _firstAsset(assets, (name) => name.endsWith('.apk') && name.contains('android')) ??
          _firstAsset(assets, (name) => name.endsWith('.apk')),
      windows: _firstAsset(assets, (name) => name.endsWith('.zip') && name.contains('windows')) ??
          _firstAsset(assets, (name) => name.endsWith('.zip') && !name.contains('source')),
    );
  }

  Future<Map<String, dynamic>> _fetchManifest(AppReleaseAsset asset, String? token) async {
    final response = await _http.get(
      Uri.parse(asset.downloadUrl),
      headers: _headers(token, download: true),
    );
    _throwIfFailed(response, 'Could not read latest.json');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('latest.json is not an object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  AppReleaseAsset _assetFromGithub(Map<String, dynamic> json) {
    return AppReleaseAsset(
      name: json['name']?.toString() ?? '',
      apiUrl: json['url']?.toString() ?? '',
      browserUrl: json['browser_download_url']?.toString() ?? '',
      size: int.tryParse(json['size']?.toString() ?? '') ?? 0,
    );
  }

  AppReleaseAsset? _firstAsset(List<AppReleaseAsset> assets, bool Function(String name) match) {
    for (final asset in assets) {
      final name = asset.name.toLowerCase();
      if (match(name)) return asset;
    }
    return null;
  }

  Map<String, String> _headers(String? token, {bool download = false}) => {
        'Accept': download ? 'application/octet-stream' : 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'biconcept-app',
        if (token != null && token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
      };

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final hint = switch (response.statusCode) {
      401 => 'GitHub rejected the token. Use a token with Contents read on $repo.',
      403 => 'GitHub blocked this check. Wait for the rate limit or add a token.',
      404 => 'No releases on $repo yet, or the token cannot see that private repo.',
      _ => response.body.trim().isEmpty ? 'HTTP ${response.statusCode}' : response.body.trim(),
    };
    throw FormatException('$action: $hint');
  }
}
