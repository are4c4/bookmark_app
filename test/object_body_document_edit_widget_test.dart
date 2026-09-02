import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dispatches text edits with the persisted block identity', (
    tester,
  ) async {
    ObjectBodyBlock? editedBlock;
    String? editedText;
    const document = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(
        id: 'paragraph-42',
        type: ObjectBodyBlockType.paragraph,
        text: 'Old',
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ObjectBodyDocumentView(
          document: document,
          onTextChanged: (block, text) {
            editedBlock = block;
            editedText = text;
          },
        ),
      ),
    ));

    final field = find.byKey(const ValueKey('body-text-paragraph-42'));
    expect(field, findsOneWidget);
    await tester.enterText(field, 'New text');
    expect(editedBlock?.id, 'paragraph-42');
    expect(editedText, 'New text');
  });

  testWidgets('remains read-only when no text callback is supplied', (
    tester,
  ) async {
    const document = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(
        id: 'paragraph-1',
        type: ObjectBodyBlockType.paragraph,
        text: 'Read only',
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ObjectBodyDocumentView(document: document)),
    ));

    expect(find.text('Read only'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
