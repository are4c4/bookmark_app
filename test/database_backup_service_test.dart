import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/person_group_store.dart';
import 'package:bookmark_app/services/database_backup_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup snapshot includes core data and person groups', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final bookmarkId = await database.addBookmark(
      url: 'https://example.com',
      title: 'Example',
      tagNames: const ['資料'],
      personNames: const ['山口一郎'],
    );
    expect(bookmarkId, greaterThan(0));

    final person = (await database.watchAllPeople().first).single;
    final groups = PersonGroupStore(database);
    final groupId = await groups.createGroup('サカナクション');
    await groups.addPerson(groupId, person.id);

    final snapshot = await DatabaseBackupService(database).createSnapshot();
    expect(snapshot['format'], 'bookmark_app_backup');
    final tables = snapshot['tables']! as Map<String, Object?>;
    expect((tables['bookmarks']! as List), isNotEmpty);
    expect((tables['tags']! as List), isNotEmpty);
    expect((tables['people']! as List), isNotEmpty);
    expect((tables['person_groups']! as List), isNotEmpty);
    expect((tables['person_group_members']! as List), isNotEmpty);
  });
}
