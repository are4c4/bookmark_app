import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ObjectType defaults accept integer and numeric-string Property ids', () {
    final defaults = ObjectTypeDefaults.fromJson(
      <String, dynamic>{
        'visiblePropertyIds': <dynamic>[1, '2'],
        'propertyOrder': <dynamic>['2', 1],
      },
    );

    expect(defaults.visiblePropertyIds, <int>[1, 2]);
    expect(defaults.propertyOrder, <int>[2, 1]);
  });

  test('ObjectType defaults reject malformed visible Property ids', () {
    expect(
      () => ObjectTypeDefaults.fromJson(
        <String, dynamic>{
          'visiblePropertyIds': <dynamic>[1, 'not-an-id', 2],
        },
      ),
      throwsFormatException,
    );
  });

  test('ObjectType defaults reject malformed Property order ids', () {
    expect(
      () => ObjectTypeDefaults.fromJson(
        <String, dynamic>{
          'propertyOrder': <dynamic>[1, true, 2],
        },
      ),
      throwsFormatException,
    );
  });
}
