import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_detail_navigation_service.dart';
import 'package:bookmark_app/data/daily_note_navigation_service.dart';
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
  test('previous/today/next return shared Object detail content', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final dailyNotes = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final service = DailyNoteDetailNavigationService(
      navigation: DailyNoteNavigationService(dailyNotes),
      detailLoader: ObjectDetailContentLoader(
        objectStore: objectStore,
        bodyStore: ObjectBodyStore(genericStore),
        computedStore: ObjectComputedValueStore(objectStore),
      ),
    );

    final today = await service.openToday(
      workspaceId: workspaceId,
      now: DateTime(2026, 9, 3, 18),
    );
    final previous = await service.openPrevious(
      workspaceId: workspaceId,
      currentDate: DateTime(2026, 9, 3),
    );
    final next = await service.openNext(
      workspaceId: workspaceId,
      currentDate: DateTime(2026, 9, 3),
    );

    expect(today.objectType.name, 'Daily Note');
    expect(previous.objectType.id, today.objectType.id);
    expect(next.objectType.id, today.objectType.id);

    final dateProperty = today.objectType.properties.singleWhere(
      (property) => property.name == 'Date',
    );
    expect(today.object.valueFor(dateProperty.id), '2026-09-03');
    expect(previous.object.valueFor(dateProperty.id), '2026-09-02');
    expect(next.object.valueFor(dateProperty.id), '2026-09-04');
  });
}
