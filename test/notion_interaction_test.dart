import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/widgets/inline_rename_text.dart';
import 'package:bookmark_app/widgets/relation_database_picker.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('inline rename commits with Enter', (tester) async {
    var value = 'Alice';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineRenameText(
            value: value,
            onSubmitted: (next) async => value = next,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Alice'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Alice'));
    await tester.pump();
    expect(find.byKey(const ValueKey('inline-rename-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('inline-rename-field')),
      'Alicia',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 400));

    expect(value, 'Alicia');
  });

  testWidgets('tag picker creates and selects query with Enter', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final initialTags = await database.watchAllTags().first;
    List<Tag>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showTagDatabasePicker(
                  context: context,
                  tags: initialTags,
                  initiallySelectedIds: const [],
                  onCreateTag: (name, parent) async {
                    final id = await database.createTag(name);
                    final tags = await database.watchAllTags().first;
                    return tags.firstWhere((tag) => tag.id == id);
                  },
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('タグDBから選択'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '恋愛');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('恋愛'), findsWidgets);
    expect(find.text('1 件選択中'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '選択'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.single.name, '恋愛');
  });

  testWidgets('people picker creates and selects name with Enter', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final initialPeople = await database.watchAllPeople().first;
    List<Person>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPeopleDatabasePicker(
                  context: context,
                  people: initialPeople,
                  initiallySelectedIds: const [],
                  onCreatePerson: (name, note) async {
                    final id = await database.createPerson(name, note: note);
                    final people = await database.watchAllPeople().first;
                    return people.firstWhere((person) => person.id == id);
                  },
                );
              },
              child: const Text('open people'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open people'));
    await tester.pumpAndSettle();
    expect(find.text('人物DBから選択'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '山田太郎');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('山田太郎'), findsWidgets);
    expect(find.text('1 人選択中'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '選択'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.single.name, '山田太郎');
  });
}
