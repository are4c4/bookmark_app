import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourceSha = '0123456789abcdef0123456789abcdef01234567';

  test(
    'release CI guard accepts successful authoritative check for source',
    () {
      final temp = Directory.systemTemp.createTempSync('release-ci-guard-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final payload = File('${temp.path}/checks.json')
        ..writeAsStringSync(
          jsonEncode({
            'total_count': 2,
            'check_runs': [
              {
                'name': 'analyze-guards',
                'conclusion': 'success',
                'head_sha': sourceSha,
              },
              {
                'name': 'merge-gate',
                'conclusion': 'success',
                'head_sha': sourceSha,
                'html_url': 'https://example.invalid/check/1',
              },
            ],
          }),
        );

      final result = Process.runSync('python3', [
        'tool/release_ci_guard.py',
        '--sha',
        sourceSha,
        '--checks-json',
        payload.path,
      ]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}', contains('Authoritative CI verified'));
    },
  );

  test(
    'release CI guard rejects missing or stale authoritative check',
    () {
      final temp = Directory.systemTemp.createTempSync('release-ci-guard-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final payload = File('${temp.path}/checks.json')
        ..writeAsStringSync(
          jsonEncode({
            'total_count': 2,
            'check_runs': [
              {
                'name': 'merge-gate',
                'conclusion': 'failure',
                'head_sha': sourceSha,
              },
              {
                'name': 'merge-gate',
                'conclusion': 'success',
                'head_sha': 'fedcba9876543210fedcba9876543210fedcba98',
              },
            ],
          }),
        );

      final result = Process.runSync('python3', [
        'tool/release_ci_guard.py',
        '--sha',
        sourceSha,
        '--checks-json',
        payload.path,
      ]);

      expect(result.exitCode, isNonZero);
      expect('${result.stderr}', contains('refusing to publish a release'));
    },
  );

  test('release CI guard requires immutable full source SHA', () {
    final result = Process.runSync('python3', [
      'tool/release_ci_guard.py',
      '--sha',
      '0123456',
      '--checks-json',
      'unused.json',
    ]);

    expect(result.exitCode, isNonZero);
    expect('${result.stderr}', contains('full 40-character Git commit SHA'));
  });
}
