import 'package:biconcept/data/app_update_service.dart';
import 'package:biconcept/data/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeVersion strips v prefix, build, and prerelease', () {
    expect(normalizeVersion('v1.2.3'), '1.2.3');
    expect(normalizeVersion('1.2.3+40'), '1.2.3');
    expect(normalizeVersion('1.2.3-beta.1'), '1.2.3');
  });

  test('compareVersions orders semver numerically', () {
    expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareVersions('1.9.9', '1.10.0'), lessThan(0));
    expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('v1.0.0', '1.0.0'), 0);
  });

  test('isRemoteNewer prefers version, then build number', () {
    expect(
      isRemoteNewer(
        currentVersion: '1.0.0',
        currentBuild: 1,
        remoteVersion: '1.0.1',
        remoteBuild: 2,
      ),
      isTrue,
    );
    expect(
      isRemoteNewer(
        currentVersion: '1.0.0',
        currentBuild: 1,
        remoteVersion: '1.0.0',
        remoteBuild: 40,
      ),
      isTrue,
    );
    expect(
      isRemoteNewer(
        currentVersion: '1.0.1',
        currentBuild: 2,
        remoteVersion: '1.0.0',
        remoteBuild: 99,
      ),
      isFalse,
    );
    expect(
      isRemoteNewer(
        currentVersion: '1.0.0',
        currentBuild: 1,
        remoteVersion: '1.0.0',
        remoteBuild: 0,
      ),
      isFalse,
    );
    expect(
      isRemoteNewer(
        currentVersion: '1.0.0',
        currentBuild: 40,
        remoteVersion: '1.0.0',
        remoteBuild: 40,
      ),
      isFalse,
    );
  });

  test('preferredReleaseAsset picks the versioned installer, not the first leftover', () {
    const assets = [
      AppReleaseAsset(
        name: 'biconcept-1.1.0-android.apk',
        apiUrl: 'https://api.github.com/1.1.0.apk',
        browserUrl: '',
      ),
      AppReleaseAsset(
        name: 'biconcept-1.1.3-android.apk',
        apiUrl: 'https://api.github.com/1.1.3.apk',
        browserUrl: '',
      ),
      AppReleaseAsset(
        name: 'biconcept-1.1.0-windows.zip',
        apiUrl: 'https://api.github.com/1.1.0.zip',
        browserUrl: '',
      ),
      AppReleaseAsset(
        name: 'biconcept-1.1.3-windows.zip',
        apiUrl: 'https://api.github.com/1.1.3.zip',
        browserUrl: '',
      ),
    ];
    expect(
      preferredReleaseAsset(
        assets,
        version: '1.1.3',
        extension: '.apk',
        platformHint: 'android',
      )?.name,
      'biconcept-1.1.3-android.apk',
    );
    expect(
      preferredReleaseAsset(
        assets,
        version: '1.1.3',
        extension: '.zip',
        platformHint: 'windows',
      )?.name,
      'biconcept-1.1.3-windows.zip',
    );
  });

  test('github download sends the token only to github.com hosts', () {
    expect(githubDownloadSendsAuth(Uri.parse('https://api.github.com/repos/x/y/releases/assets/1')), isTrue);
    expect(githubDownloadSendsAuth(Uri.parse('https://github.com/x/y/releases/download/v1/a.apk')), isTrue);
    expect(
      githubDownloadSendsAuth(Uri.parse('https://release-assets.githubusercontent.com/github-production-release-asset/1')),
      isFalse,
    );
    expect(githubDownloadSendsAuth(Uri.parse('https://objects.githubusercontent.com/foo')), isFalse);
  });

  test('installer bytes must be a zip/apk, not a GitHub HTML page', () {
    expect(looksLikeZipInstaller([0x50, 0x4B, 0x03, 0x04]), isTrue);
    expect(looksLikeWebpageOrApiError('<!DOCTYPE html><html>'.codeUnits), isTrue);
    expect(looksLikeWebpageOrApiError('{"message":"Not Found"}'.codeUnits), isTrue);
    expect(looksLikeWebpageOrApiError([0x50, 0x4B, 0x03, 0x04]), isFalse);
  });
}
