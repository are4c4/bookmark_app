import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_document_view.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 30,
}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

void _closeDatabaseAfterUnmount(
  WidgetTester tester,
  AppDatabase database,
) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();
  });
}

void main() {
  testWidgets('Object inspector fails closed on corrupt Body and can retry',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    _closeDatabaseAfterUnmount(tester, database);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
      icon: '📝',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Corrupt Body host',
    );
    await bodyStore.ensureSchema();
    await database.customStatement(
      '''INSERT INTO object_bodies(object_id, document_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(object_id)
         DO UPDATE SET document_json = excluded.document_json''',
      <Object?>[objectId, '[]'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );

    final error = find.byKey(const ValueKey('body-load-error'));
    final retry = find.byKey(const ValueKey('body-load-retry'));
    await _pumpUntil(tester, error);

    expect(error, findsOneWidget);
    expect(retry, findsOneWidget);
    expect(find.byType(ObjectBodyDocumentView), findsNothing);
    expect(find.byKey(const ValueKey('body-empty-insert')), findsNothing);
    expect(find.text('Objectが見つかりません'), findsNothing);

    final corruptRow = await database.customSelect(
      'SELECT document_json FROM object_bodies WHERE object_id = ?',
      variables: [Variable<int>(objectId)],
    ).getSingle();
    expect(corruptRow.read<String>('document_json'), '[]');

    await bodyStore.write(
      objectId: objectId,
      document: ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock.paragraph(id: 'recovered', text: 'Recovered Body'),
        ],
      ),
    );

    await tester.tap(retry);
    final recoveredField =
        find.byKey(const ValueKey('body-text-recovered'));
    await _pumpUntil(tester, recoveredField);

    expect(error, findsNothing);
    expect(find.byType(ObjectBodyDocumentView), findsOneWidget);
    expect(recoveredField, findsOneWidget);
    expect(find.text('Recovered Body'), findsOneWidget);
  });
}
