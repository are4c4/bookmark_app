import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_property_authoring_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/database/presentation/widgets/database_property_add_popover_host.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact host creates Relation through canonical authoring service',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final authoring = DatabasePropertyAuthoringService(objectStore);
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Paper',
    );
    await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Researcher',
    );
    final imageType = await SystemObjectStore(
      database: database,
      objectStore: objectStore,
    ).ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'image-test',
      name: 'Image',
      icon: '🖼️',
    );

    int? createdPropertyId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatabasePropertyAddPopoverHost(
            workspaceId: workspaceId,
            objectTypeId: sourceTypeId,
            authoring: authoring,
            hiddenProperties: const [],
            onRevealExisting: (_) {},
            onCreated: (propertyId) => createdPropertyId = propertyId,
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
    await tester.enterText(
      find.byKey(const ValueKey('property-add-create-name')),
      'Cover',
    );
    await tester.tap(
      find.byKey(const ValueKey('property-add-type-relation')),
    );
    await tester.pumpAndSettle();

    expect(find.text('組み込み ObjectType'), findsOneWidget);
    expect(find.text('カスタム ObjectType'), findsNWidgets(2));
    await tester.enterText(
      find.byKey(const ValueKey('property-add-relation-target-search')),
      'Image',
    );
    await tester.pumpAndSettle();
    expect(find.text('Researcher'), findsNothing);
    await tester.tap(
      find.byKey(ValueKey('property-add-relation-target-${imageType.id}')),
    );
    await tester.tap(find.text('single'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('property-add-create-submit')),
    );
    await tester.pumpAndSettle();

    expect(createdPropertyId, isNotNull);
    final source = (await objectStore.getObjectType(sourceTypeId))!;
    final created = source.properties.singleWhere(
      (property) => property.id == createdPropertyId,
    );
    expect(created.name, 'Cover');
    expect(created.type, ObjectPropertyType.objectRelation);
    expect(created.targetObjectTypeId, imageType.id);
    expect(created.allowsMultipleRelations, isFalse);
  });

  testWidgets('ordinary compact Property creation stays on the same authoring boundary',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Entry',
    );
    final authoring = DatabasePropertyAuthoringService(objectStore);
    int? createdPropertyId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatabasePropertyAddPopoverHost(
            workspaceId: workspaceId,
            objectTypeId: sourceTypeId,
            authoring: authoring,
            hiddenProperties: const [],
            onRevealExisting: (_) {},
            onCreated: (propertyId) => createdPropertyId = propertyId,
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
    await tester.enterText(
      find.byKey(const ValueKey('property-add-create-name')),
      'Memo',
    );
    await tester.tap(
      find.byKey(const ValueKey('property-add-create-submit')),
    );
    await tester.pumpAndSettle();

    expect(createdPropertyId, isNotNull);
    final created = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == createdPropertyId);
    expect(created.name, 'Memo');
    expect(created.type, ObjectPropertyType.text);
  });
}
