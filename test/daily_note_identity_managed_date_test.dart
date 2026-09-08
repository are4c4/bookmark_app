import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_detail_content_loader.dart';
import 'package:bookmark_app/data/object_detail_edit_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_property_management.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ensureDefinition backfills identity-managed Date metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final legacyType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: DailyNoteService.systemKey,
      name: 'Daily Note',
      icon: '📅',
    );
    final legacyDate = await systemObjects.ensureProperty(
      objectTypeId: legacyType.id,
      name: 'Date',
      type: ObjectPropertyType.date,
    );
    expect(legacyDate.isIdentityManaged, isFalse);

    final service = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final first = await service.ensureDefinition(workspaceId);
    final second = await service.ensureDefinition(workspaceId);

    expect(first.dateProperty.id, legacyDate.id);
    expect(first.dateProperty.isIdentityManaged, isTrue);
    expect(second.dateProperty.id, legacyDate.id);
    expect(second.dateProperty.isIdentityManaged, isTrue);
  });

  test(
      'generic Date edit cannot desync Daily Note identity while ordinary Date stays editable',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final loader = ObjectDetailContentLoader(
      objectStore: objectStore,
      bodyStore: bodyStore,
      computedStore: ObjectComputedValueStore(objectStore),
    );
    final edits = ObjectDetailEditService(
      objectStore: objectStore,
      bodyStore: bodyStore,
      loader: loader,
    );
    final dailyNotes = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    final note = await dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 8),
    );
    final definition = await dailyNotes.ensureDefinition(workspaceId);
    final content = (await loader.load(
      objectTypeId: definition.objectType.id,
      objectId: note.id,
    ))!;
    final dateProperty = content.objectType.properties.singleWhere(
      (property) => property.id == definition.dateProperty.id,
    );

    await expectLater(
      edits.setDate(
        content: content,
        property: dateProperty,
        value: '2026-09-09',
      ),
      throwsStateError,
    );

    final unchanged = (await loader.load(
      objectTypeId: definition.objectType.id,
      objectId: note.id,
    ))!;
    expect(unchanged.object.valueFor(dateProperty.id), '2026-09-08');
    final reopened = await dailyNotes.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 8),
    );
    expect(reopened.id, note.id);

    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Ordinary dated Object',
    );
    final ordinaryDateId = await objectStore.createProperty(
      objectTypeId: customTypeId,
      name: 'Due',
      type: ObjectPropertyType.date,
    );
    final customObjectId = await objectStore.createObject(
      objectTypeId: customTypeId,
      title: 'Editable date',
    );
    var customContent = (await loader.load(
      objectTypeId: customTypeId,
      objectId: customObjectId,
    ))!;
    final ordinaryDate = customContent.objectType.properties.singleWhere(
      (property) => property.id == ordinaryDateId,
    );

    customContent = await edits.setDate(
      content: customContent,
      property: ordinaryDate,
      value: '2026-09-10',
    );
    expect(customContent.object.valueFor(ordinaryDateId), '2026-09-10');
  });
}
