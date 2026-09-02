import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_navigation_service.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previous/next/today navigate Daily Notes by local calendar date', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final dailyNotes = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(genericStore),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final navigation = DailyNoteNavigationService(dailyNotes);

    final today = await navigation.openToday(
      workspaceId: workspaceId,
      now: DateTime(2026, 9, 3, 18, 45),
    );
    final previous = await navigation.openPrevious(
      workspaceId: workspaceId,
      currentDate: DateTime(2026, 9, 3, 22, 30),
    );
    final next = await navigation.openNext(
      workspaceId: workspaceId,
      currentDate: DateTime(2026, 9, 3, 1, 15),
    );

    expect(today.title, '2026-09-03');
    expect(previous.title, '2026-09-02');
    expect(next.title, '2026-09-04');
    expect({today.id, previous.id, next.id}.length, 3);
  });

  test('navigating to the same calendar date reuses the same Object', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final dailyNotes = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(genericStore),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final navigation = DailyNoteNavigationService(dailyNotes);

    final first = await navigation.openToday(
      workspaceId: workspaceId,
      now: DateTime(2026, 12, 31, 8),
    );
    final second = await navigation.openPrevious(
      workspaceId: workspaceId,
      currentDate: DateTime(2027, 1, 1, 23),
    );

    expect(second.id, first.id);
    expect(second.title, '2026-12-31');
  });
}
