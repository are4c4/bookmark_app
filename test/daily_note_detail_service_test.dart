import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_detail_service.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_detail_content_loader.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daily Note opens through the shared Object detail payload', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final dailyNotes = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: defaultsStore,
    );
    final service = DailyNoteDetailService(
      dailyNotes: dailyNotes,
      detailLoader: ObjectDetailContentLoader(
        objectStore: objectStore,
        bodyStore: bodyStore,
        computedStore: ObjectComputedValueStore(objectStore),
      ),
    );

    final first = await service.open(
      workspaceId: workspaceId,
      localDate: DateTime(2026, 9, 2, 8),
    );
    final second = await service.open(
      workspaceId: workspaceId,
      localDate: DateTime(2026, 9, 2, 22),
    );

    expect(second.object.id, first.object.id);
    expect(first.objectType.name, 'Daily Note');
    final dateProperty = first.objectType.properties.singleWhere(
      (property) => property.name == 'Date',
    );
    expect(first.object.valueFor(dateProperty.id), '2026-09-02');
  });
}
