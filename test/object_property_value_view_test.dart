import 'package:bookmark_app/domain/object_detail_property_presentation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_property_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ObjectDetailPropertyPresentation presentation(
  ObjectPropertyType type,
  dynamic value, {
  int id = 1,
}) =>
    ObjectDetailPropertyPresentation(
      property: ObjectPropertyDefinition(
        id: id,
        objectTypeId: 1,
        name: type.name,
        type: type,
        sortOrder: 0,
      ),
      value: value,
      displayText: type == ObjectPropertyType.objectRelation ? null : '$value',
      isHidden: false,
    );

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('MultiSelect renders semantic chips instead of comma text',
      (tester) async {
    await tester.pumpWidget(
      host(
        ObjectPropertyValueView(
          presentation: presentation(
            ObjectPropertyType.multiSelect,
            const <String>['札幌', '旅行'],
          ),
        ),
      ),
    );

    expect(find.byType(Chip), findsNWidgets(2));
    expect(find.text('札幌'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('札幌, 旅行'), findsNothing);
  });

  testWidgets('Relation renders only canonical caller-resolved labels',
      (tester) async {
    await tester.pumpWidget(
      host(
        ObjectPropertyValueView(
          presentation: presentation(
            ObjectPropertyType.objectRelation,
            const <int>[41, 42],
          ),
          relationLabels: const <String>['Alice', 'Bob'],
        ),
      ),
    );

    expect(find.byType(Chip), findsNWidgets(2));
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('41'), findsNothing);
    expect(find.text('42'), findsNothing);
  });

  testWidgets('compact presentation limits items with overflow chip',
      (tester) async {
    await tester.pumpWidget(
      host(
        ObjectPropertyValueView(
          presentation: presentation(
            ObjectPropertyType.multiSelect,
            const <String>['A', 'B', 'C'],
          ),
          density: ObjectPropertyValueDensity.compact,
          maxItems: 2,
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
  });
}
