import 'package:drift/drift.dart';

import 'app_database.dart';

const defaultPersonRoles = <String>[
  '出演者',
  '著者',
  '講師',
  '監督',
  '撮影者',
  '編集者',
  '翻訳者',
];

String normalizePersonRole(String role) {
  final value = role.trim();
  if (value == '出演' || value == 'performer') return '出演者';
  return value.isEmpty ? '出演者' : value;
}

class PersonRoleAssignment {
  const PersonRoleAssignment({required this.person, required this.role});

  final Person person;
  final String role;
}

extension AppDatabasePersonRoles on AppDatabase {
  Stream<List<PersonRoleAssignment>> watchPersonRoleAssignments(int bookmarkId) {
    final query = select(bookmarkPeople)
      ..where((relation) => relation.bookmarkId.equals(bookmarkId));

    return query.watch().asyncMap((relations) async {
      final result = <PersonRoleAssignment>[];
      for (final relation in relations) {
        final person = await (select(people)..where((p) => p.id.equals(relation.personId))).getSingleOrNull();
        if (person != null) {
          result.add(PersonRoleAssignment(person: person, role: normalizePersonRole(relation.role)));
        }
      }
      result.sort((a, b) {
        final roleOrder = a.role.compareTo(b.role);
        if (roleOrder != 0) return roleOrder;
        return a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase());
      });
      return result;
    });
  }

  Stream<List<PersonRoleAssignment>> watchRoleAssignmentsForPerson(int personId) {
    final query = select(bookmarkPeople)
      ..where((relation) => relation.personId.equals(personId));

    return query.watch().asyncMap((relations) async {
      final person = await (select(people)..where((p) => p.id.equals(personId))).getSingleOrNull();
      if (person == null) return const <PersonRoleAssignment>[];
      return relations
          .map((relation) => PersonRoleAssignment(person: person, role: normalizePersonRole(relation.role)))
          .toList();
    });
  }

  Future<void> setPeopleForRole(
    int bookmarkId,
    String role,
    Iterable<Person> selectedPeople,
  ) => transaction(() async {
        final normalizedRole = normalizePersonRole(role);
        final legacyRoles = normalizedRole == '出演者' ? const ['出演', '出演者'] : [normalizedRole];

        await (delete(bookmarkPeople)
              ..where((relation) =>
                  relation.bookmarkId.equals(bookmarkId) & relation.role.isIn(legacyRoles)))
            .go();

        for (final person in selectedPeople) {
          // Current schema allows one role per person/bookmark pair. Selecting the same
          // person under another role intentionally moves that relation to the new role.
          await into(bookmarkPeople).insert(
            BookmarkPeopleCompanion.insert(
              bookmarkId: bookmarkId,
              personId: person.id,
              role: Value(normalizedRole),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

  Future<void> removePersonRole(int bookmarkId, Person person) =>
      (delete(bookmarkPeople)
            ..where((relation) =>
                relation.bookmarkId.equals(bookmarkId) & relation.personId.equals(person.id)))
          .go();
}
