import 'package:bookmark_app/domain/object_detail_property_presentation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_detail_property_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const textProperty = ObjectPropertyDefinition(
    id: 1,
    objectTypeId: 1,
    name: 'Summary',
    type: ObjectPropertyType.text,
    sortOrder: 0,
  );

  Widget host(
    ObjectDetailPropertyPresentation presentation, {
    Widget? relationChild,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: ObjectDetailPropertyView(
            presentation: presentation,
            relationChild: relationChild,
            leading: leading,
            trailing: trailing,
            onTap: onTap,
          ),
        ),
      );

  testWidgets('renders shared label and display text', (tester) async {
    await tester.pumpWidget(host(const ObjectDetailPropertyPresentation(
      property: textProperty,
      value: 'hello',
      displayText: 'hello',
      isHidden: false,
    )));
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('omits hidden Properties', (tester) async {
    await tester.pumpWidget(host(const ObjectDetailPropertyPresentation(
      property: textProperty,
      value: 'secret',
      displayText: 'secret',
      isHidden: true,
    )));
    expect(find.text('Summary'), findsNothing);
    expect(find.text('secret'), findsNothing);
  });

  testWidgets('uses caller supplied canonical Relation renderer', (tester) async {
    const relationProperty = ObjectPropertyDefinition(
      id: 2,
      objectTypeId: 1,
      name: 'Author',
      type: ObjectPropertyType.objectRelation,
      sortOrder: 1,
      config: {'targetObjectTypeId': 2},
    );
    await tester.pumpWidget(host(
      const ObjectDetailPropertyPresentation(
        property: relationProperty,
        value: [99],
        displayText: null,
        isHidden: false,
      ),
      relationChild: const Chip(label: Text('夏目漱石')),
    ));

    expect(find.text('Author'), findsOneWidget);
    expect(find.text('夏目漱石'), findsOneWidget);
    expect(find.text('99'), findsNothing);
  });

  testWidgets('renders host-owned leading and trailing chrome', (tester) async {
    await tester.pumpWidget(host(
      const ObjectDetailPropertyPresentation(
        property: textProperty,
        value: 'hello',
        displayText: 'hello',
        isHidden: false,
      ),
      leading: const Icon(Icons.drag_indicator),
      trailing: const Icon(Icons.edit_outlined),
    ));

    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('delegates optional host edit tap without making it mandatory',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      const ObjectDetailPropertyPresentation(
        property: textProperty,
        value: 'hello',
        displayText: 'hello',
        isHidden: false,
      ),
      onTap: () => taps += 1,
    ));

    await tester.tap(find.text('hello'));
    await tester.pump();
    expect(taps, 1);
  });
}
