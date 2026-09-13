import 'package:bookmark_app/services/build_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BuildProvenance', () {
    test('formats clean stable packaged build diagnostics', () {
      const provenance = BuildProvenance(
        version: '0.1.0',
        buildNumber: '1',
        commitSha: 'db166afb0bf57fd75929ca02018b67c7d1802fe1',
        sourceState: 'clean',
        releaseChannel: 'stable',
      );

      expect(provenance.displayVersion, '0.1.0');
      expect(provenance.displayBuildNumber, '1');
      expect(provenance.shortCommit, 'db166af');
      expect(provenance.displaySourceState, 'clean');
      expect(provenance.displayReleaseChannel, 'stable');
      expect(
        provenance.compactDiagnostic,
        'Bookmark 0.1.0 (1) · stable · db166af · clean',
      );
    });

    test('keeps dirty local-development state explicit', () {
      const provenance = BuildProvenance(
        version: '0.1.0',
        buildNumber: '1',
        commitSha: 'db166afb0bf57fd75929ca02018b67c7d1802fe1',
        sourceState: 'dirty',
        releaseChannel: 'development',
      );

      expect(provenance.displaySourceState, 'dirty');
      expect(provenance.displayReleaseChannel, 'development');
      expect(provenance.compactDiagnostic, contains('· development ·'));
      expect(provenance.compactDiagnostic, endsWith('· dirty'));
    });

    test('keeps release candidate channel explicit', () {
      const provenance = BuildProvenance(
        version: '0.1.0',
        buildNumber: '1',
        commitSha: 'db166afb0bf57fd75929ca02018b67c7d1802fe1',
        sourceState: 'clean',
        releaseChannel: 'rc',
      );

      expect(provenance.displayReleaseChannel, 'rc');
      expect(provenance.compactDiagnostic, contains('· rc · db166af · clean'));
    });

    test('keeps development fallback explicit', () {
      const provenance = BuildProvenance(
        version: 'development',
        buildNumber: '0',
        commitSha: 'unknown',
        sourceState: 'development',
        releaseChannel: 'development',
      );

      expect(provenance.displayVersion, 'development');
      expect(provenance.displayBuildNumber, '0');
      expect(provenance.shortCommit, 'unknown');
      expect(provenance.displaySourceState, 'development');
      expect(provenance.displayReleaseChannel, 'development');
      expect(
        provenance.compactDiagnostic,
        'Bookmark development (0) · development · unknown · development',
      );
    });

    test('fails closed for unavailable or malformed metadata', () {
      const provenance = BuildProvenance(
        version: ' ',
        buildNumber: '',
        commitSha: '',
        sourceState: 'unexpected',
        releaseChannel: 'nightly',
      );

      expect(provenance.displayVersion, 'unknown');
      expect(provenance.displayBuildNumber, 'unknown');
      expect(provenance.shortCommit, 'unknown');
      expect(provenance.displaySourceState, 'unknown');
      expect(provenance.displayReleaseChannel, 'unknown');
    });
  });
}
