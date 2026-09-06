import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote image dimension diagnostics omit raw exception objects', () {
    final source = File(
      'lib/services/remote_image_storage_service.dart',
    ).readAsStringSync();

    expect(source, contains('catch (_, stackTrace)'));
    expect(source, contains('_debugDimensionProbeFailure(stackTrace);'));
    expect(source, contains('stackTrace: stackTrace'));

    expect(source, isNot(contains('Object error')));
    expect(source, isNot(contains('error: error')));
    expect(
      source,
      isNot(contains('_debugDimensionProbeFailure(error, stackTrace)')),
    );
  });
}
