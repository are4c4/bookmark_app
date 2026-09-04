import 'package:bookmark_app/features/object/presentation/widgets/object_body_object_reference_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidates = <ObjectBodyObjectReferenceCandidate>[
    ObjectBodyObjectReferenceCandidate(
      objectId: 1,
      title: '数論講義',
      objectTypeName: 'Book',
      objectTypeIcon: '📘',
    ),
    ObjectBodyObjectReferenceCandidate(
      objectId: 2,
      title: 'Serre',
      objectTypeName: 'Person',
      objectTypeIcon: '👤',
      aliases: <String>['ジャン＝ピエール・セール'],
    ),
  ];

  testWidgets('picker returns only an explicitly selected Object', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showObjectBodyObjectReferencePicker(
                  context,
                  candidates: candidates,
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
    expect(selected, isNull);
    await tester.tap(
      find.byKey(const ValueKey('body-object-reference-candidate-2')),
    );
    await tester.pumpAndSettle();
    expect(selected, 2);
  });

  testWidgets('picker filters by Object title or ObjectType and cancel returns null',
      (tester) async {
    int? selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showObjectBodyObjectReferencePicker(
                  context,
                  candidates: candidates,
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
    await tester.enterText(
      find.byKey(const ValueKey('body-object-reference-search')),
      'Person',
    );
    await tester.pump();
    expect(find.text('Serre'), findsOneWidget);
    expect(find.text('数論講義'), findsNothing);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('picker resolves alias matches to the canonical Object id',
      (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showObjectBodyObjectReferencePicker(
                  context,
                  candidates: candidates,
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
    await tester.enterText(
      find.byKey(const ValueKey('body-object-reference-search')),
      'セール',
    );
    await tester.pump();

    expect(find.text('Serre'), findsOneWidget);
    expect(find.text('数論講義'), findsNothing);
    expect(find.text('Person · 別名: ジャン＝ピエール・セール'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('body-object-reference-candidate-2')),
    );
    await tester.pumpAndSettle();
    expect(selected, 2);
  });
}
