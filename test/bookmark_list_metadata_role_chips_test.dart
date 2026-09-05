import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/person_roles.dart';
import 'package:bookmark_app/widgets/bookmark_list_metadata.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('role metadata renders one chip per Person instead of joined text',
      (tester) async {
    final createdAt = DateTime(2026, 9, 5);
    final people = <Person>[
      Person(id: 1, name: '今野忍', createdAt: createdAt),
      Person(id: 2, name: '箕輪厚介', createdAt: createdAt),
    ];
    final bookmark = BookmarkItem(
      id: 1,
      url: 'https://example.com',
      title: 'Example',
      createdAt: createdAt,
      favorite: false,
      status: 'unread',
      rating: 0,
      openCount: 0,
      tags: const [],
      people: const [],
      photos: const [],
      collections: const [],
    );
    final assignments = people
        .map((person) => PersonRoleAssignment(person: person, role: '著者'))
        .toList(growable: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookmarkListMetadata(
            bookmark: bookmark,
            assignments: assignments,
            propertyTokens: const ['role:著者'],
          ),
        ),
      ),
    );

    expect(find.text('著者:'), findsOneWidget);
    expect(find.text('今野忍'), findsOneWidget);
    expect(find.text('箕輪厚介'), findsOneWidget);
    expect(find.text('今野忍、箕輪厚介'), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsNWidgets(2));
  });
}
