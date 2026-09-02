import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/widgets/object_body_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(ObjectBodyDocument document, Future<void> Function(String) onSave) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ObjectBodySection(document: document, onSave: onSave),
      ),
    ),
  );
}

void main() {
  testWidgets('paragraph Body is displayed and can be edited', (tester) async {
    String? saved;
    final document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock.paragraph(id: 'p1', text: 'first paragraph'),
      ],
    );

    await tester.pumpWidget(host(document, (text) async => saved = text));

    expect(find.text('first paragraph'), findsOneWidget);
    expect(find.byKey(const ValueKey('object-body-edit-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object-body-edit-button')));
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('object-body-editor'));
    expect(editor, findsOneWidget);

    await tester.enterText(editor, 'updated body');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, 'updated body');
  });

  testWidgets('empty Body offers a write affordance', (tester) async {
    await tester.pumpWidget(
      host(const ObjectBodyDocument(), (text) async {}),
    );

    expect(find.text('本文はまだありません。'), findsOneWidget);
    expect(find.text('書き始める'), findsOneWidget);
  });

  testWidgets('rich Body is protected from plain-text editing', (tester) async {
    const document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(id: 'code-1', type: 'code', text: 'print(1)'),
      ],
    );

    await tester.pumpWidget(host(document, (text) async {}));

    expect(find.byKey(const ValueKey('object-body-edit-button')), findsNothing);
    expect(find.textContaining('リッチブロック'), findsOneWidget);
  });
}
