import 'package:bookmark_app/data/database_view_property_schema_service.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/object_property_delete_impact_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ObjectPropertyDeleteImpact _impact({
  int storedValues = 0,
  List<DatabaseViewPropertyReference> viewReferences = const [],
}) => ObjectPropertyDeleteImpact(
      property: const ObjectPropertyDefinition(
        id: 7,
        objectTypeId: 3,
        name: 'Cover',
        type: ObjectPropertyType.objectRelation,
        sortOrder: 0,
        config: {
          'targetObjectTypeId': 9,
          'multiple': false,
        },
      ),
      objectsWithStoredValue: storedValues,
      viewReferences: viewReferences,
    );

const _viewReference = DatabaseViewPropertyReference(
  viewId: 12,
  viewName: 'お気に入り',
  kinds: {
    DatabaseViewPropertyReferenceKind.filter,
    DatabaseViewPropertyReferenceKind.sort,
    DatabaseViewPropertyReferenceKind.galleryCover,
  },
);

void main() {
  testWidgets('unused Property can be explicitly confirmed for deletion',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showObjectPropertyDeleteImpactDialog(
                  context,
                  impact: _impact(),
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

    expect(find.text('「Cover」を削除'), findsOneWidget);
    expect(find.text('値を保存しているObject'), findsOneWidget);
    expect(find.text('0件'), findsNWidgets(3));
    final deleteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('property-delete-confirm')),
    );
    expect(deleteButton.onPressed, isNotNull);

    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('stored values and View references keep deletion disabled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectPropertyDeleteImpactDialog(
            impact: _impact(
              storedValues: 4,
              viewReferences: const [_viewReference],
            ),
          ),
        ),
      ),
    );

    expect(find.text('4件'), findsOneWidget);
    expect(find.text('1件'), findsOneWidget);
    expect(find.text('お気に入り'), findsOneWidget);
    expect(
      find.text('フィルター / 並び替え / ギャラリーカバー'),
      findsOneWidget,
    );
    expect(
      find.textContaining('この状態では削除できません'),
      findsOneWidget,
    );
    final deleteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('property-delete-confirm')),
    );
    expect(deleteButton.onPressed, isNull);
  });

  testWidgets('a View reference alone is enough to block deletion',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectPropertyDeleteImpactDialog(
            impact: _impact(
              viewReferences: const [
                DatabaseViewPropertyReference(
                  viewId: 5,
                  viewName: '一覧',
                  kinds: {
                    DatabaseViewPropertyReferenceKind.visible,
                    DatabaseViewPropertyReferenceKind.order,
                    DatabaseViewPropertyReferenceKind.group,
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('表示 / プロパティ順 / グループ'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('property-delete-confirm')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('explicit View detach refreshes impact and unlocks deletion',
      (tester) async {
    bool? result;
    var detachCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showObjectPropertyDeleteImpactDialog(
                  context,
                  impact: _impact(viewReferences: const [_viewReference]),
                  onDetachViewReferences: () async {
                    detachCalls += 1;
                    return _impact();
                  },
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

    expect(find.text('お気に入り'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('property-delete-confirm')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('property-delete-detach-views')),
    );
    await tester.pumpAndSettle();

    expect(detachCalls, 1);
    expect(find.text('お気に入り'), findsNothing);
    expect(find.textContaining('このPropertyを削除できます'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('property-delete-confirm')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('failed View detach stays blocked and hides raw error details',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectPropertyDeleteImpactDialog(
            impact: _impact(viewReferences: const [_viewReference]),
            onDetachViewReferences: () async {
              throw StateError('secret database implementation detail');
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('property-delete-detach-views')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('property-delete-detach-error')),
      findsOneWidget,
    );
    expect(find.textContaining('secret database'), findsNothing);
    expect(find.text('お気に入り'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('property-delete-confirm')),
          )
          .onPressed,
      isNull,
    );
  });
}
