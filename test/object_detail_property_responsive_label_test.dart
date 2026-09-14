import 'package:bookmark_app/domain/object_detail_property_presentation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_detail_property_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const property = ObjectPropertyDefinition(
    id: 1,
    objectTypeId: 1,
    name: 'Representative preview image',
    type: ObjectPropertyType.text,
    sortOrder: 0,
  );
  const presentation = ObjectDetailPropertyPresentation(
    property: property,
    value: 'preview',
    displayText: 'preview',
    isHidden: false,
  );

  Widget host(double width) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: const ObjectDetailPropertyView(presentation: presentation),
        ),
      ),
    ),
  );

  testWidgets('uses wider bounded Property labels on full-page width', (
    tester,
  ) async {
    await tester.pumpWidget(host(800));

    final labelGrid = find.byKey(const ValueKey('object-property-label-grid'));
    expect(
      tester.getSize(labelGrid).width,
      ObjectDetailPropertyView.maxPropertyLabelWidth,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Property labels compact on narrow detail width', (
    tester,
  ) async {
    await tester.pumpWidget(host(300));

    final labelGrid = find.byKey(const ValueKey('object-property-label-grid'));
    expect(
      tester.getSize(labelGrid).width,
      ObjectDetailPropertyView.minPropertyLabelWidth,
    );
    expect(tester.takeException(), isNull);
  });
}
