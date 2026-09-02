import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_actions.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('document supplies current block positions to action builder', (tester) async {
    const document = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph, text: 'A'),
      ObjectBodyBlock(id: 'b', type: ObjectBodyBlockType.paragraph, text: 'B'),
    ]);
    final seen = <String, ObjectBodyBlockPosition>{};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ObjectBodyDocumentView(
          document: document,
          blockActionsBuilder: (context, block, position) {
            seen[block.id] = position;
            return Text('actions-${block.id}');
          },
        ),
      ),
    ));

    expect(find.text('actions-a'), findsOneWidget);
    expect(find.text('actions-b'), findsOneWidget);
    expect(seen['a']!.canMoveUp, isFalse);
    expect(seen['a']!.canMoveDown, isTrue);
    expect(seen['b']!.canMoveUp, isTrue);
    expect(seen['b']!.canMoveDown, isFalse);
  });

  testWidgets('document remains action-free when no builder is supplied', (tester) async {
    const document = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph, text: 'A'),
    ]);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ObjectBodyDocumentView(document: document)),
    ));

    expect(find.byKey(const ValueKey('object-body-block-a')), findsOneWidget);
    expect(find.textContaining('actions-'), findsNothing);
  });
}
