import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('optional generic Weblink enrichment diagnostics omit raw exceptions', () {
    final source = File(
      'lib/data/generic_database_object_create_service.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'Optional post-create Weblink enrichment failed; canonical Weblink is kept.',
      ),
    );
    expect(source, contains('stackTrace: stackTrace'));
    expect(source, contains('catch (_, stackTrace)'));
    expect(source, isNot(contains('catch (error, stackTrace)')));
    expect(source, isNot(contains('Object error')));
    expect(source, isNot(contains('error: error')));
  });
}
