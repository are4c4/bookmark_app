import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_property_authoring_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/database/presentation/widgets/database_property_add_popover_host.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _createQuickProperty(
  WidgetTester tester, {
  required String name,
  required String typeKey,
}) async {
  await tester.tap(find.text('追加'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('property-add-create-new')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('property-add-create-name')),
    name,
  );
  await tester.tap(find.byKey(ValueKey('property-add-type-$typeKey')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('property-add-create-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'quick add creates Select and Multi-select through authoring service',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final objectStore = ObjectStore(GenericDatabaseStore(database));
      final objectTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Book',
      );
      final authoring = DatabasePropertyAuthoringService(objectStore);
      final createdIds = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatabasePropertyAddPopoverHost(
              workspaceId: workspaceId,
              objectTypeId: objectTypeId,
              authoring: authoring,
              hiddenProperties: const [],
              onRevealExisting: (_) {},
              onCreated: createdIds.add,
              buttonLabel: '追加',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('property-add-create-new')));
      await tester.pumpAndSettle();
      expect(find.text('セレクト'), findsOneWidget);
      expect(find.text('マルチセレクト'), findsOneWidget);
      expect(find.text('リレーション'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _createQuickProperty(tester, name: '状態', typeKey: 'select');
      await _createQuickProperty(tester, name: '分類', typeKey: 'multiSelect');

      expect(createdIds, hasLength(2));
      final objectType = (await objectStore.getObjectType(objectTypeId))!;
      final select = objectType.properties.singleWhere(
        (property) => property.id == createdIds[0],
      );
      final multiSelect = objectType.properties.singleWhere(
        (property) => property.id == createdIds[1],
      );
      expect(select.name, '状態');
      expect(select.type, ObjectPropertyType.select);
      expect(multiSelect.name, '分類');
      expect(multiSelect.type, ObjectPropertyType.multiSelect);
    },
  );
}
