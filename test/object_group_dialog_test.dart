import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/object_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const properties = <ObjectPropertyDefinition>[
  ObjectPropertyDefinition(
    id: 10,
    objectTypeId: 1,
    name: 'ステータス',
    type: ObjectPropertyType.select,
    sortOrder: 0,
  ),
  ObjectPropertyDefinition(
    id: 11,
    objectTypeId: 1,
    name: 'タグ',
    type: ObjectPropertyType.multiSelect,
    sortOrder: 1,
  ),
  ObjectPropertyDefinition(
    id: 12,
    objectTypeId: 1,
    name: '計算値',
    type: ObjectPropertyType.formula,
    sortOrder: 2,
  ),
  ObjectPropertyDefinition(
    id: 13,
    objectTypeId: 1,
    name: '画像',
    type: ObjectPropertyType.image,
    sortOrder: 3,
  ),
];

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows groupable properties and excludes images', (tester) async {
    await tester.pumpWidget(
      host(const ObjectGroupDialog(properties: properties)),
    );

    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();

    expect(find.text('ステータス'), findsOneWidget);
    expect(find.text('タグ'), findsOneWidget);
    expect(find.text('計算値'), findsOneWidget);
    expect(find.text('画像'), findsNothing);
  });

  testWidgets('returns selected property and include-empty setting', (tester) async {
    ObjectGroupDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showObjectGroupDialog(
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
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ステータス').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('適用'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.rule?.propertyId, 10);
    expect(result!.rule?.includeEmpty, isFalse);
  });

  testWidgets('can clear an existing group rule', (tester) async {
    ObjectGroupDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showObjectGroupDialog(
                  context,
                  properties: properties,
                  initialRule: const ObjectGroupRule(propertyId: 11),
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
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('グループ化しない').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('適用'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.rule, isNull);
  });
}
