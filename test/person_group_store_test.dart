import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/person_group_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('person groups support multiple memberships', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = PersonGroupStore(database);

    final yamaguchiId = await database.createPerson('山口一郎');
    final sakanaId = await store.createGroup('サカナクション');
    final projectId = await store.createGroup('NF');

    await store.setGroupsForPerson(yamaguchiId, [sakanaId, projectId]);

    final memberships = await store.groupsForPerson(yamaguchiId);
    expect(
      memberships.map((group) => group.name).toSet(),
      {'サカナクション', 'NF'},
    );
    expect(await store.memberIds(sakanaId), contains(yamaguchiId));
    expect(await store.memberIds(projectId), contains(yamaguchiId));
  });

  test('deleting a group keeps the person record', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = PersonGroupStore(database);

    final personId = await database.createPerson('山口一郎');
    final groupId = await store.createGroup('サカナクション');
    await store.addPerson(groupId, personId);

    await store.deleteGroup(groupId);

    final people = await database.watchAllPeople().first;
    expect(people.any((person) => person.id == personId), isTrue);
    expect(await store.groupsForPerson(personId), isEmpty);
  });
}
