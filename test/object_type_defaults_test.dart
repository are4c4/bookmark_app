import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ObjectTypeDefaultsResolver();

  test('ObjectType defaults override app fallback without copying View state', () {
    final resolved = resolver.resolve(
      appFallback: const ObjectTypeDefaults(
        visiblePropertyIds: <int>[1, 2],
        propertyOrder: <int>[1, 2, 3],
        openMode: ObjectOpenMode.sidePeek,
      ),
      objectTypeDefaults: const ObjectTypeDefaults(
        visiblePropertyIds: <int>[2, 3],
        openMode: ObjectOpenMode.fullPage,
      ),
    );

    expect(resolved.visiblePropertyIds, <int>[2, 3]);
    expect(resolved.propertyOrder, <int>[1, 2, 3]);
    expect(resolved.openMode, ObjectOpenMode.fullPage);
  });

  test('app fallback supplies sensible defaults when ObjectType is silent', () {
    final resolved = resolver.resolve(
      appFallback: const ObjectTypeDefaults(
        visiblePropertyIds: <int>[7],
        propertyOrder: <int>[7, 8],
        openMode: ObjectOpenMode.centerPeek,
      ),
    );

    expect(resolved.visiblePropertyIds, <int>[7]);
    expect(resolved.propertyOrder, <int>[7, 8]);
    expect(resolved.openMode, ObjectOpenMode.centerPeek);
  });

  test('resolver has a stable app-level open-mode fallback', () {
    final resolved = resolver.resolve(
      appFallback: const ObjectTypeDefaults(),
    );

    expect(resolved.visiblePropertyIds, isEmpty);
    expect(resolved.propertyOrder, isEmpty);
    expect(resolved.openMode, ObjectOpenMode.sidePeek);
  });
}
