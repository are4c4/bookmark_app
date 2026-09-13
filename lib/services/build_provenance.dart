/// Compile-time provenance for one Bookmark application build.
///
/// Release packaging injects these values with `--dart-define`. Runtime code
/// never reads the live Git checkout, so an installed build keeps the identity
/// of the source tree that produced it.
class BuildProvenance {
  const BuildProvenance({
    required this.version,
    required this.buildNumber,
    required this.commitSha,
    required this.sourceState,
  });

  static const current = BuildProvenance(
    version: String.fromEnvironment(
      'BOOKMARK_APP_VERSION',
      defaultValue: 'development',
    ),
    buildNumber: String.fromEnvironment(
      'BOOKMARK_APP_BUILD_NUMBER',
      defaultValue: '0',
    ),
    commitSha: String.fromEnvironment(
      'BOOKMARK_GIT_SHA',
      defaultValue: 'unknown',
    ),
    sourceState: String.fromEnvironment(
      'BOOKMARK_SOURCE_STATE',
      defaultValue: 'development',
    ),
  );

  final String version;
  final String buildNumber;
  final String commitSha;
  final String sourceState;

  String get displayVersion => _normalizedOrUnknown(version);

  String get displayBuildNumber => _normalizedOrUnknown(buildNumber);

  String get shortCommit {
    final value = _normalizedOrUnknown(commitSha);
    if (value == 'unknown' || value.length <= 7) return value;
    return value.substring(0, 7);
  }

  String get displaySourceState {
    return switch (sourceState.trim().toLowerCase()) {
      'clean' => 'clean',
      'dirty' => 'dirty',
      'development' => 'development',
      _ => 'unknown',
    };
  }

  String get compactDiagnostic =>
      'Bookmark $displayVersion ($displayBuildNumber) · '
      '$shortCommit · $displaySourceState';
}

String _normalizedOrUnknown(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? 'unknown' : normalized;
}
