import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/object_relation_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppObject _object(int id, int objectTypeId, String title) => AppObject(
      id: id,
      objectTypeId: objectTypeId,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

RelationSelectionContext _selection({List<AppObject> candidates = const []}) {
  const sourceTypeId = 10;
  const targetTypeId = 20;
  const property = ObjectPropertyDefinition(
    id: 30,
    objectTypeId: sourceTypeId,
    name: 'Cover',
    type: ObjectPropertyType.objectRelation,
    sortOrder: 0,
    config: <String, dynamic>{
      'targetObjectTypeId': targetTypeId,
      'multiple': false,
    },
  );
  return RelationSelectionContext(
    sourceObject: _object(1, sourceTypeId, 'Source'),
    property: property,
    targetObjectType: const AppObjectType(
      id: targetTypeId,
      workspaceId: 1,
      name: 'Image',
      icon: '🖼️',
      kind: ObjectTypeKind.system,
      sortOrder: 0,
    ),
    candidates: candidates,
    selectedObjectIds: const [],
    selectedObjects: const [],
    missingTargetObjectIds: const [],
    hasCardinalityViolation: false,
  );
}

void main() {
  testWidgets('managed quick-create is available without search input',
      (tester) async {
    final created = _object(42, 20, 'Imported image');
    var createCalls = 0;
    String? receivedInput;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectRelationPickerDialog(
            selection: _selection(),
            onSearch: ({required context, required query}) async => const [],
            onQuickCreate: (query) async {
              createCalls += 1;
              receivedInput = query;
              return created.id;
            },
            onReloadAfterQuickCreate: () async =>
                _selection(candidates: <AppObject>[created]),
            quickCreateLabel: (_) => '画像をインポート',
            quickCreateRequiresInput: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('object-relation-picker-quick-create')),
      findsOneWidget,
    );
    expect(find.text('画像をインポート'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('object-relation-picker-quick-create')),
    );
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(receivedInput, '');
    expect(find.text('1件選択'), findsOneWidget);
    expect(find.byKey(const ValueKey('object-relation-picker-error')), findsNothing);
  });

  testWidgets('text quick-create still requires non-empty search input',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectRelationPickerDialog(
            selection: _selection(),
            onSearch: ({required context, required query}) async => const [],
            onQuickCreate: (_) async => 42,
            onReloadAfterQuickCreate: () async => _selection(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('object-relation-picker-quick-create')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('object-relation-picker-search')),
      'New target',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('object-relation-picker-quick-create')),
      findsOneWidget,
    );
  });
}
