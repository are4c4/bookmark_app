import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_alias_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Object inspector adds and removes persisted aliases',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final aliasStore = ObjectAliasStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: '夏目漱石',
    );
    await aliasStore.addAlias(objectId: objectId, alias: '漱石');

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('object-alias-editor')), findsOneWidget);
    expect(find.byKey(const ValueKey('object-alias-chip:漱石')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object-alias-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-alias-add-field')),
      'Natsume Soseki',
    );
    await tester.tap(find.byKey(const ValueKey('object-alias-add-save')));
    await tester.pumpAndSettle();

    expect(
      await aliasStore.listAliases(objectId),
      ['漱石', 'Natsume Soseki'],
    );
    expect(
      find.byKey(const ValueKey('object-alias-chip:Natsume Soseki')),
      findsOneWidget,
    );

    final existingChip = tester.widget<InputChip>(
      find.byKey(const ValueKey('object-alias-chip:漱石')),
    );
    existingChip.onDeleted!.call();
    await tester.pumpAndSettle();

    expect(await aliasStore.listAliases(objectId), ['Natsume Soseki']);
    expect(find.byKey(const ValueKey('object-alias-chip:漱石')), findsNothing);
  });
}
