import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:bookmark_app/widgets/object_query_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const properties = <ObjectPropertyDefinition>[
  ObjectPropertyDefinition(
    id: 10,
    objectTypeId: 1,
    name: '評価',
    type: ObjectPropertyType.number,
    sortOrder: 0,
  ),
  ObjectPropertyDefinition(
    id: 11,
    objectTypeId: 1,
    name: 'タグ',
    type: ObjectPropertyType.multiSelect,
    sortOrder: 1,
  ),
];

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows existing filter and sort rules', (tester) async {
    await tester.pumpWidget(
      host(
        const ObjectQueryDialog(
          properties: properties,
          initialFilters: [
            ObjectFilterRule(
              propertyId: 10,
              operator: ObjectFilterOperator.greaterThan,
              value: 3,
            ),
          ],
          initialSorts: [
            ObjectSortRule(
              propertyId: 10,
              direction: ObjectSortDirection.descending,
            ),
          ],
        ),
      ),
    );

    expect(find.text('フィルターと並び替え'), findsOneWidget);
    expect(find.text('評価'), findsWidgets);
    expect(find.text('より大きい'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('並び替え'));
    await tester.pumpAndSettle();
    expect(find.text('降順'), findsOneWidget);
  });

  testWidgets('adds a filter and returns it on apply', (tester) async {
    ObjectQueryDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showObjectQueryDialog(
                  context,
                  properties: properties,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('フィルターを追加'));
    await tester.pumpAndSettle();

    final valueField = find.widgetWithText(TextFormField, '値');
    expect(valueField, findsOneWidget);
    await tester.enterText(valueField, 'math');
    await tester.tap(find.text('適用'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.filters, hasLength(1));
    expect(result!.filters.single.propertyId, isNull);
    expect(result!.filters.single.operator, ObjectFilterOperator.contains);
    expect(result!.filters.single.value, 'math');
  });

  testWidgets('adds an ascending sort rule', (tester) async {
    ObjectQueryDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showObjectQueryDialog(
                  context,
                  properties: properties,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('並び替え'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('並び替えを追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('適用'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.sorts, hasLength(1));
    expect(result!.sorts.single.propertyId, isNull);
    expect(result!.sorts.single.direction, ObjectSortDirection.ascending);
  });

  testWidgets('value-less filter hides the value editor', (tester) async {
    await tester.pumpWidget(
      host(
        const ObjectQueryDialog(
          properties: properties,
          initialFilters: [
            ObjectFilterRule(
              propertyId: 10,
              operator: ObjectFilterOperator.isEmpty,
            ),
          ],
        ),
      ),
    );

    expect(find.text('空'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '値'), findsNothing);
  });
}
