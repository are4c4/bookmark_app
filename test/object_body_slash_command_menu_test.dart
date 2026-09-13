import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_body_editor.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_editor_section.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_slash_command_menu.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slash invocation removes only the command token', () {
    const block = ObjectBodyBlock(
      id: 'p',
      type: ObjectBodyBlockType.paragraph,
      text: 'hello /h2',
    );

    final invocation = ObjectBodySlashCommandInvocation.tryParse(
      objectId: 7,
      block: block,
      text: 'hello /h2',
    );

    expect(invocation, isNotNull);
    expect(invocation!.query, 'h2');
    expect(invocation.replacementText, 'hello ');
    expect(invocation.commandStart, 6);
    expect(
      ObjectBodySlashCommandInvocation.tryParse(
        objectId: 7,
        block: block,
        text: 'https://example.com',
      ),
      isNull,
    );
  });

  test('same-kind conversion can atomically clean slash text', () {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'p',
          type: ObjectBodyBlockType.paragraph,
          text: 'hello /paragraph',
          attributes: <String, dynamic>{'align': 'center'},
        ),
      ],
    );

    final converted = const ObjectBodyEditor().convertBlock(
      document: document,
      blockId: 'p',
      targetType: ObjectBodyBlockType.paragraph,
      replacementText: 'hello ',
    );

    expect(identical(converted, document), isFalse);
    expect(converted.blocks.single.text, 'hello ');
    expect(converted.blocks.single.attributes, {'align': 'center'});
  });

  testWidgets('slash filtering converts through persisted Body boundary', (
    tester,
  ) async {
    final fixture = await _fixture('Slash conversion');
    addTearDown(fixture.database.close);
    await fixture.bodyStore.write(
      objectId: fixture.objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p', type: 'paragraph', text: ''),
        ],
      ),
    );

    await _pumpEditor(tester, fixture, fixture.objectId);
    await tester.enterText(find.byType(TextField), 'hello /h2');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('body-slash-command-menu')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('body-slash-command-heading-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('body-slash-command-heading-1')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('body-slash-command-heading-2')));
    await tester.pumpAndSettle();

    final stored = await fixture.bodyStore.read(fixture.objectId);
    expect(stored.blocks.single.id, 'p');
    expect(stored.blocks.single.type, ObjectBodyBlockType.heading);
    expect(stored.blocks.single.text, 'hello ');
    expect(
      stored.blocks.single.attributes[ObjectBodyBlockAttribute.level],
      2,
    );
    expect(find.byKey(const ValueKey('body-slash-command-menu')), findsNothing);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
  });

  testWidgets('divider slash command uses canonical insert path', (tester) async {
    final fixture = await _fixture('Slash divider');
    addTearDown(fixture.database.close);
    await fixture.bodyStore.write(
      objectId: fixture.objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p', type: 'paragraph', text: ''),
        ],
      ),
    );

    await _pumpEditor(tester, fixture, fixture.objectId);
    await tester.enterText(find.byType(TextField), '/div');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('body-slash-command-divider')));
    await tester.pumpAndSettle();

    final stored = await fixture.bodyStore.read(fixture.objectId);
    expect(stored.blocks, hasLength(2));
    expect(stored.blocks.first.id, 'p');
    expect(stored.blocks.first.text, '');
    expect(stored.blocks.last.type, ObjectBodyBlockType.divider);
  });

  testWidgets('Escape dismisses slash menu without structural mutation', (
    tester,
  ) async {
    final fixture = await _fixture('Slash escape');
    addTearDown(fixture.database.close);
    await fixture.bodyStore.write(
      objectId: fixture.objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p', type: 'paragraph', text: ''),
        ],
      ),
    );

    await _pumpEditor(tester, fixture, fixture.objectId);
    await tester.enterText(find.byType(TextField), '/');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('body-slash-command-menu')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('body-slash-command-menu')), findsNothing);
    final stored = await fixture.bodyStore.read(fixture.objectId);
    expect(stored.blocks, hasLength(1));
    expect(stored.blocks.single.type, ObjectBodyBlockType.paragraph);
    expect(stored.blocks.single.text, '/');
  });

  testWidgets('switching Objects clears stale slash command UI', (tester) async {
    final fixture = await _fixture('Slash switch');
    addTearDown(fixture.database.close);
    final secondObjectId = await fixture.objectStore.createObject(
      objectTypeId: fixture.objectTypeId,
      title: 'Second',
    );
    await fixture.bodyStore.write(
      objectId: fixture.objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p1', type: 'paragraph', text: ''),
        ],
      ),
    );
    await fixture.bodyStore.write(
      objectId: secondObjectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p2', type: 'paragraph', text: 'second'),
        ],
      ),
    );

    await _pumpEditor(tester, fixture, fixture.objectId);
    await tester.enterText(find.byType(TextField), '/h1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('body-slash-command-menu')), findsOneWidget);

    await _pumpEditor(tester, fixture, secondObjectId);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('body-slash-command-menu')), findsNothing);
    final second = await fixture.bodyStore.read(secondObjectId);
    expect(second.blocks.single.type, ObjectBodyBlockType.paragraph);
    expect(second.blocks.single.text, 'second');
  });
}

Future<
    ({
      AppDatabase database,
      int workspaceId,
      GenericDatabaseStore store,
      ObjectStore objectStore,
      ObjectBodyStore bodyStore,
      int objectTypeId,
      int objectId,
    })> _fixture(String title) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final workspaceId = await WorkspaceStore(database).initialize();
  final store = GenericDatabaseStore(database);
  final objectStore = ObjectStore(store);
  final objectTypeId = await objectStore.createObjectType(
    workspaceId: workspaceId,
    name: 'Note',
  );
  final objectId = await objectStore.createObject(
    objectTypeId: objectTypeId,
    title: title,
  );
  return (
    database: database,
    workspaceId: workspaceId,
    store: store,
    objectStore: objectStore,
    bodyStore: ObjectBodyStore(store),
    objectTypeId: objectTypeId,
    objectId: objectId,
  );
}

Future<void> _pumpEditor(
  WidgetTester tester,
  ({
    AppDatabase database,
    int workspaceId,
    GenericDatabaseStore store,
    ObjectStore objectStore,
    ObjectBodyStore bodyStore,
    int objectTypeId,
    int objectId,
  }) fixture,
  int objectId,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ObjectBodyEditorSection(
          store: fixture.store,
          objectStore: fixture.objectStore,
          objectId: objectId,
          workspaceId: fixture.workspaceId,
          showHeading: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
