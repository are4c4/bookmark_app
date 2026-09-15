import 'package:bookmark_app/domain/object_detail_property_presentation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_detail_property_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const property = ObjectPropertyDefinition(
    id: 1,
    objectTypeId: 1,
    name: 'Optional note',
    type: ObjectPropertyType.text,
    sortOrder: 0,
  );

  testWidgets('blank scalar metadata follows quiet-empty presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectDetailPropertyView(
            presentation: ObjectDetailPropertyPresentation(
              property: property,
              value: '   ',
              displayText: '   ',
              isHidden: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Optional note'), findsNothing);
    expect(find.text('   '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty computed Properties preserve their shared renderer', (
    tester,
  ) async {
    const computedProperty = ObjectPropertyDefinition(
      id: 2,
      objectTypeId: 1,
      name: 'Formula result',
      type: ObjectPropertyType.formula,
      sortOrder: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectDetailPropertyView(
            presentation: ObjectDetailPropertyPresentation(
              property: computedProperty,
              value: null,
              displayText: 'なし',
              isHidden: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Formula result'), findsOneWidget);
    expect(find.text('なし'), findsOneWidget);
    expect(find.byIcon(Icons.functions), findsOneWidget);
  });
}
