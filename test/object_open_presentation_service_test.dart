import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_open_mode_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_open_presentation_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads ObjectType default and still gives View override precedence', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final defaults = ObjectTypeDefaultsStore(genericStore);
    await defaults.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.centerPeek),
    );

    final viewStore = DatabaseViewStore(database);
    const definition = DatabaseDefinition(
      key: 'custom:notes',
      label: 'Notes',
      icon: Icons.note_outlined,
      properties: <DatabasePropertyDefinition>[],
      defaultLayout: 'list',
      supportedLayouts: <String>['list'],
    );
    final viewId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'All',
      settings: const <String, dynamic>{'openMode': 'fullPage'},
    );
    final view = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .singleWhere((candidate) => candidate.id == viewId);
    final service = ObjectOpenPresentationService(
      viewOpenModes: DatabaseViewOpenModeService(viewStore),
      objectTypeDefaults: defaults,
    );

    expect(
      await service.resolve(view: view, objectTypeId: typeId),
      ObjectOpenMode.fullPage,
    );
    expect(
      await service.resolve(
        view: view.copyWith(settings: const <String, dynamic>{}),
        objectTypeId: typeId,
      ),
      ObjectOpenMode.centerPeek,
    );
  });
}
