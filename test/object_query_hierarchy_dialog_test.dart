import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:bookmark_app/widgets/object_query_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const hierarchyProperties = <ObjectPropertyDefinition>[
  ObjectPropertyDefinition(
    id: 12,
    objectTypeId: 1,
    name: '分類タグ',
    type: ObjectPropertyType.objectRelation,
    sortOrder: 0,
    config: <String, dynamic>{'targetObjectTypeId': 2, 'multiple': true},
  ),
];

void main() {
  testWidgets('hierarchy-aware Relation preserves its saved match mode', (
    tester,
  ) async {
    ObjectQueryDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showObjectQueryDialog(
                  context,
                  properties: hierarchyProperties,
                  hierarchyAwarePropertyIds: const <int>{12},
                  initialFilters: const <ObjectFilterRule>[
                    ObjectFilterRule(
                      propertyId: 12,
                      operator: ObjectFilterOperator.containsAny,
                      value: <int>[42],
                      hierarchyMatchMode: ObjectHierarchyMatchMode.isOrBelow,
                    ),
                  ],
                );
              },
              child: const Text('open hierarchy'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open hierarchy'));
    await tester.pumpAndSettle();

    expect(find.text('階層'), findsOneWidget);
    expect(find.text('配下を含む'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '値'), findsOneWidget);

    await tester.tap(find.text('適用'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.filters.single.propertyId, 12);
    expect(
      result!.filters.single.hierarchyMatchMode,
      ObjectHierarchyMatchMode.isOrBelow,
    );
    expect(result!.filters.single.value, <int>[42]);
  });

  testWidgets('hidden hierarchy capability does not erase a saved mode', (
    tester,
  ) async {
    ObjectQueryDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showObjectQueryDialog(
                  context,
                  properties: hierarchyProperties,
                  initialFilters: const <ObjectFilterRule>[
                    ObjectFilterRule(
                      propertyId: 12,
                      operator: ObjectFilterOperator.containsAny,
                      value: <int>[42],
                      hierarchyMatchMode: ObjectHierarchyMatchMode.belowOnly,
                    ),
                  ],
                );
              },
              child: const Text('open hidden hierarchy'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open hidden hierarchy'));
    await tester.pumpAndSettle();

    expect(find.text('階層'), findsNothing);
    await tester.tap(find.text('適用'));
    await tester.pumpAndSettle();

    expect(
      result!.filters.single.hierarchyMatchMode,
      ObjectHierarchyMatchMode.belowOnly,
    );
  });
}
