import 'package:bookmark_app/domain/object_detail_property_presentation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_detail_property_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const populatedProperty = ObjectPropertyDefinition(
    id: 1,
    objectTypeId: 1,
    name: 'Title metadata',
    type: ObjectPropertyType.text,
    sortOrder: 0,
  );
  const emptyProperty = ObjectPropertyDefinition(
    id: 2,
    objectTypeId: 1,
    name: 'Optional note',
    type: ObjectPropertyType.text,
    sortOrder: 1,
  );
  const computedProperty = ObjectPropertyDefinition(
    id: 3,
    objectTypeId: 1,
    name: 'Formula result',
    type: ObjectPropertyType.formula,
    sortOrder: 2,
  );

  ObjectDetailPropertyPresentation presentation(
    ObjectPropertyDefinition property,
    dynamic value,
  ) => ObjectDetailPropertyPresentation(
    property: property,
    value: value,
    displayText: value == null ? 'なし' : '$value',
    isHidden: false,
  );

  testWidgets('shares policy classification with reveal interaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectDetailPropertySection(
            presentations: [
              presentation(populatedProperty, 'visible'),
              presentation(emptyProperty, null),
              presentation(computedProperty, null),
            ],
            itemBuilder: (_, item) => Text(
              item.property.name,
              key: ValueKey('property-${item.property.id}'),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('property-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('property-2')), findsNothing);
    expect(find.byKey(const ValueKey('property-3')), findsOneWidget);
    expect(find.text('空のプロパティを表示 (1)'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('object-detail-show-empty-properties')),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('property-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('property-3')), findsOneWidget);
  });
}
