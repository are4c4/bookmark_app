import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_open_mode_service.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DatabaseViewStore store;
  late DatabaseViewOpenModeService service;
  late int workspaceId;

  const definition = DatabaseDefinition(
    key: 'custom:notes',
    label: 'Notes',
    icon: Icons.note_outlined,
    properties: <DatabasePropertyDefinition>[],
    defaultLayout: 'list',
    supportedLayouts: <String>['list'],
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    store = DatabaseViewStore(database);
    service = DatabaseViewOpenModeService(store);
  });

  tearDown(() => database.close());

  Future<DatabaseViewConfig> createView({Map<String, dynamic> settings = const {}}) async {
    final id = await store.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'All',
      settings: settings,
    );
    return (await store.listViews(
      workspaceId: workspaceId,
      databaseKey: definition.key,
    ))
        .singleWhere((view) => view.id == id);
  }

  test('resolution follows View then Database then ObjectType then app', () async {
    final view = await createView(
      settings: const <String, dynamic>{'openMode': 'centerPeek'},
    );

    expect(
      service.resolve(
        view: view,
        databaseOverride: ObjectOpenMode.fullPage,
        objectTypeDefault: ObjectOpenMode.sidePeek,
      ),
      ObjectOpenMode.centerPeek,
    );

    final withoutView = view.copyWith(settings: const <String, dynamic>{});
    expect(
      service.resolve(
        view: withoutView,
        databaseOverride: ObjectOpenMode.fullPage,
        objectTypeDefault: ObjectOpenMode.centerPeek,
      ),
      ObjectOpenMode.fullPage,
    );
    expect(
      service.resolve(
        view: withoutView,
        objectTypeDefault: ObjectOpenMode.centerPeek,
      ),
      ObjectOpenMode.centerPeek,
    );
    expect(service.resolve(view: withoutView), ObjectOpenMode.sidePeek);
  });

  test('setOverride persists and clearing restores inherited behavior', () async {
    final view = await createView(
      settings: const <String, dynamic>{'density': 'compact'},
    );

    final overridden = await service.setOverride(
      view: view,
      mode: ObjectOpenMode.fullPage,
    );
    expect(overridden.settings['density'], 'compact');
    expect(service.overrideFor(overridden), ObjectOpenMode.fullPage);

    final cleared = await service.setOverride(view: overridden, mode: null);
    expect(cleared.settings['density'], 'compact');
    expect(cleared.settings.containsKey('openMode'), isFalse);
    expect(service.overrideFor(cleared), isNull);
  });

  test('malformed persisted View override fails closed', () async {
    final view = await createView(
      settings: const <String, dynamic>{'openMode': 'floatingWindow'},
    );

    expect(() => service.overrideFor(view), throwsFormatException);
  });
}
