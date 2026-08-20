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
}
