import 'package:bookmark_app/domain/object_detail_property_presentation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_detail_property_view.dart';
import 'package:bookmark_app/features/object/presentation/widgets/property_drag_handle.dart';
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

  testWidgets('hidden Properties suppress host chrome and interaction',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      const ObjectDetailPropertyPresentation(
        property: textProperty,
        value: 'secret',
        displayText: 'secret',
        isHidden: true,
      ),
      leading: const Icon(Icons.drag_indicator),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => taps += 1,
    ));

    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(taps, 0);
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

  testWidgets('normalizes reorder chrome to six dots on the Property first line',
      (tester) async {
    await tester.pumpWidget(host(
      const ObjectDetailPropertyPresentation(
        property: textProperty,
        value: 'hello',
        displayText: 'hello',
        isHidden: false,
      ),
      leading: ReorderableDragStartListener(
        index: 0,
        child: const Icon(
          Icons.drag_indicator,
          key: ValueKey('material-drag-glyph'),
          size: 15,
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('material-drag-glyph')), findsNothing);
    expect(find.byType(PropertyDragHandle), findsOneWidget);

    final handleCenter = tester.getCenter(
      find.byKey(const ValueKey('property-six-dot-handle')),
    );
    final labelCenter = tester.getCenter(find.text('Summary'));
    expect((handleCenter.dy - labelCenter.dy).abs(), lessThanOrEqualTo(1.0));

    expect(
      tester.getSize(find.byKey(const ValueKey('object-property-handle-slot'))),
      const Size(
        ObjectDetailPropertyView.handleSlotWidth,
        ObjectDetailPropertyView.firstLineHeight,
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('object-property-icon-slot'))),
      const Size(
        ObjectDetailPropertyView.propertyIconSlotWidth,
        ObjectDetailPropertyView.firstLineHeight,
      ),
    );
  });

  testWidgets('multi-line Relation value does not move handle or Property name',
      (tester) async {
    const relationProperty = ObjectPropertyDefinition(
      id: 2,
      objectTypeId: 1,
      name: 'Authors',
      type: ObjectPropertyType.objectRelation,
      sortOrder: 1,
      config: {'targetObjectTypeId': 2, 'multiple': true},
    );
    await tester.pumpWidget(host(
      const ObjectDetailPropertyPresentation(
        property: relationProperty,
        value: [10, 11, 12],
        displayText: null,
        isHidden: false,
      ),
      leading: ReorderableDragStartListener(
        index: 0,
        child: const Icon(Icons.drag_indicator),
      ),
      relationChild: const SizedBox(
        key: ValueKey('multi-line-relation-value'),
        height: 72,
        child: Align(
          alignment: Alignment.topLeft,
          child: Text('Serre\nTate\nGrothendieck'),
        ),
      ),
    ));

    final handleSlot = find.byKey(const ValueKey('object-property-handle-slot'));
    final labelGrid = find.byKey(const ValueKey('object-property-label-grid'));
    final value = find.byKey(const ValueKey('multi-line-relation-value'));

    expect(tester.getSize(value).height, 72);
    expect(tester.getTopLeft(handleSlot).dy, tester.getTopLeft(labelGrid).dy);
    expect(
      tester.getSize(handleSlot).height,
      ObjectDetailPropertyView.firstLineHeight,
    );
    expect(
      tester.getSize(labelGrid).height,
      ObjectDetailPropertyView.firstLineHeight,
    );
    expect(
      (tester.getCenter(find.byType(PropertyDragHandle)).dy -
              tester.getCenter(find.text('Authors')).dy)
          .abs(),
      lessThanOrEqualTo(1.0),
    );
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
