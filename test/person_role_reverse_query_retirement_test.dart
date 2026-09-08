import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('caller-zero Person role legacy APIs stay retired', () {
    final repositorySource =
        File('lib/data/bookmark_repository.dart').readAsStringSync();
    final personRoleSource = File('lib/data/person_roles.dart').readAsStringSync();

    expect(repositorySource, contains('watchPersonRoles(BookmarkItem bookmark)'));
    expect(personRoleSource, contains('watchPersonRoleAssignments(int bookmarkId)'));

    expect(repositorySource, isNot(contains('watchRolesForPerson(')));
    expect(personRoleSource, isNot(contains('watchRoleAssignmentsForPerson(')));
    expect(repositorySource, isNot(contains('removePersonFromBookmark(')));
    expect(personRoleSource, isNot(contains('removePersonRole(')));
  });
}
