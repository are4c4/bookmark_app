import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/domain/object_identity_search.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/object_relation_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppObject _object(int id, int typeId, String title) => AppObject(
      id: id,
      objectTypeId: typeId,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

RelationSelectionContext _selection({
  required bool multiple,
  required List<AppObject> candidates,
  List<int> selected = const <int>[],
}) {
  const sourceTypeId = 10;
  const targetTypeId = 20;
  final property = ObjectPropertyDefinition(
    id: 30,
    objectTypeId: sourceTypeId,
    name: 'Authors',
    type: ObjectPropertyType.objectRelation,
    sortOrder: 0,
    config: <String, dynamic>{
      'targetObjectTypeId': targetTypeId,
      'multiple': multiple,
    },
  );
  final byId = <int, AppObject>{for (final object in candidates) object.id: object};
  return RelationSelectionContext(
    sourceObject: _object(1, sourceTypeId, 'Source'),
    property: property,
    targetObjectType: const AppObjectType(
      id: targetTypeId,
      workspaceId: 1,
      name: 'Person',
      icon: '👤',
      kind: ObjectTypeKind.custom,
      sortOrder: 0,
    ),
    candidates: candidates,
    selectedObjectIds: selected,
    selectedObjects: selected.map((id) => byId[id]).whereType<AppObject>().toList(),
    missingTargetObjectIds: selected.where((id) => !byId.containsKey(id)).toList(),
    hasCardinalityViolation: !multiple && selected.length > 1,
  );
}

List<ObjectIdentitySearchResult> _searchResults(RelationSelectionContext context) =>
    context.candidates
        .map(
          (object) => ObjectIdentitySearchResult(
            object: object,
            objectType: context.targetObjectType,
            aliases: const <String>[],
          ),
        )
        .toList(growable: false);

Widget _host({
  required RelationSelectionContext selection,
  required ValueChanged<ObjectRelationPickerResult?> onResult,
  required ObjectRelationPickerSearch onSearch,
  ObjectRelationPickerQuickCreate? onQuickCreate,
  ObjectRelationPickerReload? onReload,
}) =>
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              onResult(
                await showObjectRelationPickerDialog(
                  context: context,
                  selection: selection,
                  onSearch: onSearch,
                  onQuickCreate: onQuickCreate,
                  onReloadAfterQuickCreate: onReload,
                  quickCreateLabel: (query) => '「$query」を新規作成',
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('normal selection returns the canonical context used by save', (tester) async {
    final first = _object(101, 20, 'Alice');
    final second = _object(102, 20, 'Bob');
    final selection = _selection(
      multiple: true,
      candidates: <AppObject>[first, second],
    );
    ObjectRelationPickerResult? result;

    await tester.pumpWidget(
      _host(
        selection: selection,
        onResult: (value) => result = value,
        onSearch: ({required context, required query}) async =>
            _searchResults(context)
                .where((item) => item.canonicalTitle.toLowerCase().contains(query.toLowerCase()))
                .toList(),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob'));
    await tester.tap(find.byKey(const ValueKey('object-relation-picker-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.context, same(selection));
    expect(result!.selectedObjectIds, <int>{102});
  });

  testWidgets('quick-create reloads candidates and returns refreshed context', (tester) async {
    final first = _object(101, 20, 'Alice');
    final created = _object(103, 20, 'Carol');
    final initial = _selection(
      multiple: true,
      candidates: <AppObject>[first],
    );
    final refreshed = _selection(
      multiple: true,
      candidates: <AppObject>[first, created],
    );
    ObjectRelationPickerResult? result;
    var reloadCount = 0;

    await tester.pumpWidget(
      _host(
        selection: initial,
        onResult: (value) => result = value,
        onSearch: ({required context, required query}) async => _searchResults(context),
        onQuickCreate: (query) async {
          expect(query, 'Carol');
          return created.id;
        },
        onReload: () async {
          reloadCount++;
          return refreshed;
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-relation-picker-search')),
      'Carol',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('object-relation-picker-quick-create')));
    await tester.pumpAndSettle();

    expect(reloadCount, 1);
    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('1件選択'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object-relation-picker-save')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.context, same(refreshed));
    expect(result!.selectedObjectIds, <int>{created.id});
  });

  testWidgets('single Relation quick-create replaces stale in-dialog selection', (tester) async {
    final first = _object(101, 20, 'Alice');
    final created = _object(102, 20, 'Bob');
    final initial = _selection(
      multiple: false,
      candidates: <AppObject>[first],
      selected: <int>[first.id],
    );
    final refreshed = _selection(
      multiple: false,
      candidates: <AppObject>[first, created],
      selected: <int>[first.id],
    );
    ObjectRelationPickerResult? result;

    await tester.pumpWidget(
      _host(
        selection: initial,
        onResult: (value) => result = value,
        onSearch: ({required context, required query}) async => _searchResults(context),
        onQuickCreate: (_) async => created.id,
        onReload: () async => refreshed,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-relation-picker-search')),
      'Bob',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('object-relation-picker-quick-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('object-relation-picker-save')));
    await tester.pumpAndSettle();

    expect(result!.context, same(refreshed));
    expect(result!.selectedObjectIds, <int>{created.id});
  });

  testWidgets('quick-create fails closed when refreshed canonical candidates omit created Object',
      (tester) async {
    final first = _object(101, 20, 'Alice');
    final initial = _selection(
      multiple: true,
      candidates: <AppObject>[first],
    );
    ObjectRelationPickerResult? result;

    await tester.pumpWidget(
      _host(
        selection: initial,
        onResult: (value) => result = value,
        onSearch: ({required context, required query}) async => _searchResults(context),
        onQuickCreate: (_) async => 999,
        onReload: () async => initial,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-relation-picker-search')),
      'Missing',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('object-relation-picker-quick-create')));
    await tester.pumpAndSettle();

    expect(
      find.text('作成したObjectをRelation候補として確認できませんでした。'),
      findsOneWidget,
    );
    expect(find.text('0件選択'), findsOneWidget);
    expect(result, isNull);
  });
}
