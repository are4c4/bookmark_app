import 'package:bookmark_app/data/database_view_query_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/object_query_engine.dart';
import 'package:bookmark_app/data/object_view_projector.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseViewConfig view({
  Map<String, dynamic> filters = const <String, dynamic>{},
}) => DatabaseViewConfig(
  id: 1,
  workspaceId: 1,
  databaseKey: 'custom:1',
  name: 'すべて',
  layoutType: 'table',
  filters: filters,
  sorts: const [],
  visibleProperties: const [],
  propertyOrder: const [],
  settings: const {},
  sortOrder: 0,
);

AppObject object(
  int id,
  String title, {
  Map<int, dynamic> values = const <int, dynamic>{},
}) => AppObject(
  id: id,
  objectTypeId: 1,
  title: title,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  values: values,
);

void main() {
  const adapter = DatabaseViewQueryAdapter();
  const engine = ObjectQueryEngine();

  test('View query round-trips hierarchy mode and legacy rules stay exact', () {
    final encoded = adapter.encode(
      view(),
      filters: const [
        ObjectFilterRule(
          propertyId: 12,
          operator: ObjectFilterOperator.containsAny,
          value: [101],
          hierarchyMatchMode: ObjectHierarchyMatchMode.isOrBelow,
        ),
      ],
    );

    final storedRules = encoded.filters['propertyRules'] as List<dynamic>;
    expect((storedRules.single as Map)['hierarchyMatchMode'], 'isOrBelow');
    expect(
      adapter.decode(encoded).filters.single.hierarchyMatchMode,
      ObjectHierarchyMatchMode.isOrBelow,
    );

    final legacy = adapter.decode(
      view(
        filters: const {
          'propertyRules': [
            {
              'propertyId': 12,
              'operator': 'containsAny',
              'value': [101],
            },
          ],
        },
      ),
    );
    expect(
      legacy.filters.single.hierarchyMatchMode,
      ObjectHierarchyMatchMode.exact,
    );
  });

  test('saved View projection forwards the canonical hierarchy matcher', () {
    const fruit = 101;
    const apple = 102;
    const greenApple = 103;
    const parents = <int, int?>{fruit: null, apple: fruit, greenApple: apple};

    bool isStrictDescendant(int descendantId, int ancestorId) {
      var current = parents[descendantId];
      final visited = <int>{descendantId};
      while (current != null && visited.add(current)) {
        if (current == ancestorId) return true;
        current = parents[current];
      }
      return false;
    }

    final savedView = adapter.encode(
      view(),
      filters: const [
        ObjectFilterRule(
          propertyId: 20,
          operator: ObjectFilterOperator.containsAny,
          value: [fruit],
          hierarchyMatchMode: ObjectHierarchyMatchMode.isOrBelow,
        ),
      ],
    );
    final projection = const ObjectViewProjector().project(
      objects: [
        object(
          1,
          'Green apple',
          values: {
            20: [greenApple],
          },
        ),
      ],
      view: savedView,
      hierarchyDescendantMatcher: isStrictDescendant,
    );

    expect(projection.objects.map((item) => item.id), [1]);
  });

  test('malformed hierarchy mode is ignored during saved rule decode', () {
    final decoded = adapter.decode(
      view(
        filters: const {
          'propertyRules': [
            {
              'propertyId': 12,
              'operator': 'containsAny',
              'value': [101],
              'hierarchyMatchMode': 'recursiveMagic',
            },
          ],
        },
      ),
    );

    expect(decoded.filters, isEmpty);
  });

  test(
    'hierarchy modes distinguish exact, descendant and excluded branches',
    () {
      const tagPropertyId = 20;
      const fruit = 101;
      const apple = 102;
      const greenApple = 103;
      const vegetable = 201;
      final parents = <int, int?>{
        fruit: null,
        apple: fruit,
        greenApple: apple,
        vegetable: null,
      };

      bool isStrictDescendant(int descendantId, int ancestorId) {
        var current = parents[descendantId];
        final visited = <int>{descendantId};
        while (current != null && visited.add(current)) {
          if (current == ancestorId) return true;
          current = parents[current];
        }
        return false;
      }

      final objects = [
        object(
          1,
          'Direct fruit',
          values: {
            tagPropertyId: [fruit],
          },
        ),
        object(
          2,
          'Green apple',
          values: {
            tagPropertyId: [greenApple],
          },
        ),
        object(
          3,
          'Vegetable',
          values: {
            tagPropertyId: [vegetable],
          },
        ),
        object(4, 'Untagged'),
      ];

      Iterable<int> idsFor(ObjectHierarchyMatchMode mode) => engine
          .apply(
            objects: objects,
            filters: [
              ObjectFilterRule(
                propertyId: tagPropertyId,
                operator: ObjectFilterOperator.containsAny,
                value: const [fruit],
                hierarchyMatchMode: mode,
              ),
            ],
            hierarchyDescendantMatcher: isStrictDescendant,
          )
          .map((item) => item.id);

      expect(idsFor(ObjectHierarchyMatchMode.exact), [1]);
      expect(idsFor(ObjectHierarchyMatchMode.isOrBelow), [1, 2]);
      expect(idsFor(ObjectHierarchyMatchMode.belowOnly), [2]);
      expect(idsFor(ObjectHierarchyMatchMode.excludeBranch), [3, 4]);
    },
  );

  test('non-exact hierarchy filter fails closed without canonical matcher', () {
    final result = engine.apply(
      objects: [
        object(
          1,
          'Child',
          values: {
            20: [103],
          },
        ),
      ],
      filters: const [
        ObjectFilterRule(
          propertyId: 20,
          operator: ObjectFilterOperator.containsAny,
          value: [101],
          hierarchyMatchMode: ObjectHierarchyMatchMode.isOrBelow,
        ),
      ],
    );

    expect(result, isEmpty);
  });

  test('containsAll hierarchy mode requires a match in every branch', () {
    final objects = [
      object(
        1,
        'Both',
        values: {
          20: [103, 203],
        },
      ),
      object(
        2,
        'Fruit only',
        values: {
          20: [103],
        },
      ),
    ];
    const parents = <int, int?>{
      101: null,
      102: 101,
      103: 102,
      201: null,
      202: 201,
      203: 202,
    };

    bool isStrictDescendant(int descendantId, int ancestorId) {
      var current = parents[descendantId];
      final visited = <int>{descendantId};
      while (current != null && visited.add(current)) {
        if (current == ancestorId) return true;
        current = parents[current];
      }
      return false;
    }

    final result = engine.apply(
      objects: objects,
      filters: const [
        ObjectFilterRule(
          propertyId: 20,
          operator: ObjectFilterOperator.containsAll,
          value: [101, 201],
          hierarchyMatchMode: ObjectHierarchyMatchMode.isOrBelow,
        ),
      ],
      hierarchyDescendantMatcher: isStrictDescendant,
    );

    expect(result.map((item) => item.id), [1]);
  });
}
