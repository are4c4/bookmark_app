import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/object_property_delete_impact_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ObjectPropertyDeleteImpact _impact({
  List<DatabaseViewPropertyReference> views = const [],
}) =>
    ObjectPropertyDeleteImpact(
      property: const ObjectPropertyDefinition(
        id: 10,
        objectTypeId: 1,
        name: 'Amount',
        type: ObjectPropertyType.number,
        sortOrder: 0,
      ),
      objectsWithStoredValue: 0,
      viewReferences: views,
      computedReferences: const [
        ObjectPropertyComputedReference(
          objectTypeId: 1,
          objectTypeName: 'Order',
          propertyId: 11,
          propertyName: 'Double Amount',
          kind: ObjectPropertyComputedReferenceKind.formula,
        ),
      ],
    );

void main() {
  testWidgets('computed schema reference keeps delete disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showObjectPropertyDeleteImpactDialog(
                context,
                impact: _impact(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('参照しているFormula/Rollup'), findsOneWidget);
    expect(find.text('Double Amount'), findsOneWidget);
    expect(find.text('Order · Formula参照'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('property-delete-confirm')),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('detaching Views does not bypass a remaining computed blocker',
      (tester) async {
    final initial = _impact(
      views: const [
        DatabaseViewPropertyReference(
          viewId: 20,
          viewName: 'Table',
          kinds: {DatabaseViewPropertyReferenceKind.visible},
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showObjectPropertyDeleteImpactDialog(
                context,
                impact: initial,
                onDetachViewReferences: () async => _impact(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('property-delete-detach-views')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Table'), findsNothing);
    expect(find.text('Double Amount'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('property-delete-confirm')),
    );
    expect(confirm.onPressed, isNull);
  });
}
