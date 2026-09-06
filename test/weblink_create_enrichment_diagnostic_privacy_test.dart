import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Weblink enrichment diagnostics do not log raw exception objects', () {
    final source = File(
      'lib/services/weblink_create_enrichment_service.dart',
    ).readAsStringSync();

    expect(source, contains("_debugFailure('metadata fetch', stackTrace);"));
    expect(
      source,
      contains("_debugFailure('metadata persistence', stackTrace);"),
    );
    expect(source, contains("_debugFailure('preview ingestion', stackTrace);"));
    expect(source, contains('stackTrace: stackTrace'));

    expect(source, isNot(contains('catch (error, stackTrace)')));
    expect(source, isNot(contains('Object error')));
    expect(source, isNot(contains('error: error')));
  });
}
