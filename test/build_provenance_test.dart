import 'package:bookmark_app/services/build_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BuildProvenance', () {
    test('formats clean packaged build diagnostics', () {
      const provenance = BuildProvenance(
        version: '0.1.0',
        buildNumber: '1',
        commitSha: 'db166afb0bf57fd75929ca02018b67c7d1802fe1',
        sourceState: 'clean',
      );

      expect(provenance.displayVersion, '0.1.0');
      expect(provenance.displayBuildNumber, '1');
      expect(provenance.shortCommit, 'db166af');
      expect(provenance.displaySourceState, 'clean');
      expect(
        provenance.compactDiagnostic,
        'Bookmark 0.1.0 (1) · db166af · clean',
      );
    });

    test('keeps dirty state explicit', () {
      const provenance = BuildProvenance(
        version: '0.1.0',
        buildNumber: '1',
        commitSha: 'db166afb0bf57fd75929ca02018b67c7d1802fe1',
        sourceState: 'dirty',
      );

      expect(provenance.displaySourceState, 'dirty');
      expect(provenance.compactDiagnostic, contains('· dirty'));
    });

    test('keeps development fallback explicit', () {
      const provenance = BuildProvenance(
        version: 'development',
        buildNumber: '0',
        commitSha: 'unknown',
        sourceState: 'development',
      );

      expect(provenance.displayVersion, 'development');
      expect(provenance.displayBuildNumber, '0');
      expect(provenance.shortCommit, 'unknown');
      expect(provenance.displaySourceState, 'development');
      expect(
        provenance.compactDiagnostic,
        'Bookmark development (0) · unknown · development',
      );
    });

    test('fails closed for unavailable or malformed metadata', () {
      const provenance = BuildProvenance(
        version: ' ',
        buildNumber: '',
        commitSha: '',
        sourceState: 'unexpected',
      );

      expect(provenance.displayVersion, 'unknown');
      expect(provenance.displayBuildNumber, 'unknown');
      expect(provenance.shortCommit, 'unknown');
      expect(provenance.displaySourceState, 'unknown');
    });
  });
}
