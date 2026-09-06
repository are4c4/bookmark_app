import 'package:bookmark_app/features/database/presentation/widgets/relation_property_authoring_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const targets = [
    RelationPropertyTargetOption(
      objectTypeId: 1,
      name: 'Image',
      icon: '🖼️',
      isBuiltIn: true,
    ),
    RelationPropertyTargetOption(
      objectTypeId: 2,
      name: 'Weblink',
      icon: '🔗',
      isBuiltIn: true,
    ),
    RelationPropertyTargetOption(
      objectTypeId: 3,
      name: 'Plant',
      icon: '🌱',
      isBuiltIn: false,
    ),
  ];

  Widget host({
    int? selectedTargetObjectTypeId,
    bool multiple = true,
    ValueChanged<int?>? onTargetChanged,
    ValueChanged<bool>? onMultipleChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: RelationPropertyAuthoringFields(
            targets: targets,
            selectedTargetObjectTypeId: selectedTargetObjectTypeId,
            multiple: multiple,
            onTargetChanged: onTargetChanged ?? (_) {},
            onMultipleChanged: onMultipleChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('search distinguishes built-in and custom ObjectTypes',
      (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const ValueKey('relation-property-target-search')));
    await tester.pump();

    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Weblink'), findsOneWidget);
    expect(find.text('Plant'), findsOneWidget);
    expect(find.text('組み込み ObjectType'), findsNWidgets(2));
    expect(find.text('カスタム ObjectType'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('relation-property-target-search')),
      'カスタム',
    );
    await tester.pump();

    expect(find.text('Plant'), findsOneWidget);
    expect(find.text('Image'), findsNothing);
    expect(find.text('Weblink'), findsNothing);
  });

  testWidgets('selecting a target reports canonical ObjectType id',
      (tester) async {
    int? selected;
    await tester.pumpWidget(host(onTargetChanged: (value) => selected = value));

    await tester.tap(find.byKey(const ValueKey('relation-property-target-search')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('relation-property-target-2')));
    await tester.pump();

    expect(selected, 2);
    expect(find.byKey(const ValueKey('relation-property-target-results')), findsNothing);
  });

  testWidgets('selected target is visible and can be explicitly cleared',
      (tester) async {
    int? changedTo = 99;
    await tester.pumpWidget(
      host(
        selectedTargetObjectTypeId: 1,
        onTargetChanged: (value) => changedTo = value,
      ),
    );

    final targetField = tester.widget<TextField>(
      find.byKey(const ValueKey('relation-property-target-search')),
    );
    expect(targetField.decoration?.hintText, contains('Image'));
    await tester.tap(find.byKey(const ValueKey('relation-property-target-clear')));
    await tester.pump();

    expect(changedTo, isNull);
    expect(find.byKey(const ValueKey('relation-property-target-results')), findsOneWidget);
  });

  testWidgets('single and multi cardinality are explicit choices',
      (tester) async {
    bool? changedTo;
    await tester.pumpWidget(
      host(
        multiple: true,
        onMultipleChanged: (value) => changedTo = value,
      ),
    );

    expect(find.text('single'), findsOneWidget);
    expect(find.text('multi'), findsOneWidget);
    expect(find.text('複数のObjectを関連付けできます'), findsOneWidget);

    await tester.tap(find.text('single'));
    await tester.pump();

    expect(changedTo, isFalse);
  });
}
