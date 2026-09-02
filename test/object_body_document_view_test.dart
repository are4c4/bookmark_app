import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = ObjectBodyBlockFactory();

  Widget host(ObjectBodyDocument document, {
    void Function(ObjectBodyBlock block, bool checked)? onChecklistChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ObjectBodyDocumentView(
          document: document,
          onChecklistChanged: onChecklistChanged,
          emptyBuilder: (_) => const Text('Empty body'),
        ),
      ),
    );
  }

  testWidgets('renders blocks in persisted order', (tester) async {
    final document = ObjectBodyDocument(
      version: 1,
      blocks: [
        factory.paragraph(id: 'p1', text: 'First'),
        factory.heading(id: 'h1', level: 2, text: 'Second'),
        factory.paragraph(id: 'p2', text: 'Third'),
      ],
    );
    await tester.pumpWidget(host(document));

    final first = tester.getTopLeft(find.text('First')).dy;
    final second = tester.getTopLeft(find.text('Second')).dy;
    final third = tester.getTopLeft(find.text('Third')).dy;
    expect(first, lessThan(second));
    expect(second, lessThan(third));
  });

  testWidgets('preserves block identity when dispatching edits', (tester) async {
    ObjectBodyBlock? changedBlock;
    bool? changedValue;
    final document = ObjectBodyDocument(
      version: 1,
      blocks: [factory.checklist(id: 'check-7', text: 'Task')],
    );
    await tester.pumpWidget(host(
      document,
      onChecklistChanged: (block, checked) {
        changedBlock = block;
        changedValue = checked;
      },
    ));

    await tester.tap(find.byType(Checkbox));
    expect(changedBlock?.id, 'check-7');
    expect(changedValue, isTrue);
  });

  testWidgets('uses explicit empty state without inventing a paragraph', (
    tester,
  ) async {
    const document = ObjectBodyDocument(version: 1, blocks: []);
    await tester.pumpWidget(host(document));
    expect(find.text('Empty body'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });
}
