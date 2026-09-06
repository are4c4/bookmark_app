import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('person role Property add uses the shared anchored popover', () async {
    final source = await File(
      'lib/widgets/person_role_properties.dart',
    ).readAsString();

    expect(source, contains('PropertyAddPopover('));
    expect(
      source,
      contains("buttonKey: const ValueKey('person-role-property-add')"),
    );
    expect(source, contains('normalizePersonRole(request.name)'));
    expect(
      source,
      isNot(contains("title: const Text('人物プロパティを追加')")),
    );
  });
}
