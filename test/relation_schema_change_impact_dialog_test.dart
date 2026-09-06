import 'package:bookmark_app/data/relation_schema_evolution_service.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/relation_schema_change_impact_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _property = ObjectPropertyDefinition(
  id: 7,
  objectTypeId: 2,
  name: 'Images',
  type: ObjectPropertyType.objectRelation,
  sortOrder: 0,
  config: {
    'targetObjectTypeId': 10,
    'multiple': true,
  },
);

RelationSchemaChangeImpact _impact({
  int nextTargetObjectTypeId = 10,
  bool nextMultiple = false,
  int affectedSourceObjectCount = 2,
  Map<int, List<int>> conflicts = const <int, List<int>>{},
}) =>
    RelationSchemaChangeImpact(
      property: _property,
      currentTargetObjectTypeId: 10,
      nextTargetObjectTypeId: nextTargetObjectTypeId,
      currentMultiple: true,
      nextMultiple: nextMultiple,
      affectedSourceObjectCount: affectedSourceObjectCount,
      multiToSingleConflicts: conflicts,
    );

void main() {
  testWidgets('shows target/cardinality impact summary and affected count',
      (tester) async {
    RelationSchemaChangeConfirmation? confirmation;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                confirmation = await showRelationSchemaChangeImpactDialog(
                  context: context,
                  impact: _impact(
                    nextTargetObjectTypeId: 11,
                    nextMultiple: false,
                    affectedSourceObjectCount: 0,
                  ),
                  currentTargetLabel: 'Image',
                  nextTargetLabel: 'File',
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

    expect(
      find.byKey(const ValueKey('relation-schema-target-change')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('relation-schema-cardinality-change')),
      findsOneWidget,
    );
    expect(find.text('Image  →  File'), findsOneWidget);
    expect(find.text('multi  →  single'), findsOneWidget);
    expect(find.text('値が入っているObject: 0件'), findsOneWidget);

    await tester.tap(find.text('変更を続ける'));
    await tester.pumpAndSettle();

    expect(confirmation, isNotNull);
    expect(confirmation!.multiToSingleSelections, isEmpty);
  });

  testWidgets('multi to single requires an explicit choice for every conflict',
      (tester) async {
    RelationSchemaChangeConfirmation? confirmation;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                confirmation = await showRelationSchemaChangeImpactDialog(
                  context: context,
                  impact: _impact(
                    conflicts: const {
                      100: [1, 2],
                      101: [3, 4],
                    },
                  ),
                  currentTargetLabel: 'Image',
                  nextTargetLabel: 'Image',
                  sourceObjectLabels: const {
                    100: 'Book A',
                    101: 'Book B',
                  },
                  targetObjectLabels: const {
                    1: 'Cover A',
                    2: 'Cover B',
                    3: 'Cover C',
                    4: 'Cover D',
                  },
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

    final confirmButton = find.byKey(const ValueKey('relation-schema-confirm'));
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
    expect(find.text('Book A'), findsOneWidget);
    expect(find.text('Book B'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('relation-schema-choice-100')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cover B').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('relation-schema-choice-101')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cover D').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(confirmation, isNotNull);
    expect(
      confirmation!.multiToSingleSelections,
      const {100: 2, 101: 4},
    );
  });
}
