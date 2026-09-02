import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_body_block_presentation.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_block_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = ObjectBodyBlockFactory();
  const presenter = ObjectBodyBlockPresenter();

  Widget host(ObjectBodyBlockPresentation presentation, {
    ValueChanged<bool>? onChecklistChanged,
    VoidCallback? onObjectReferenceTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ObjectBodyBlockView(
          presentation: presentation,
          onChecklistChanged: onChecklistChanged,
          onObjectReferenceTap: onObjectReferenceTap,
        ),
      ),
    );
  }

  testWidgets('renders heading and code metadata', (tester) async {
    await tester.pumpWidget(host(presenter.present(
      factory.heading(id: 'h1', level: 2, text: 'Heading'),
    )));
    expect(find.text('Heading'), findsOneWidget);

    await tester.pumpWidget(host(presenter.present(
      factory.code(id: 'c1', text: 'print(1)', language: 'dart'),
    )));
    expect(find.text('dart'), findsOneWidget);
    expect(find.text('print(1)'), findsOneWidget);
  });

  testWidgets('dispatches checklist changes', (tester) async {
    bool? changed;
    await tester.pumpWidget(host(
      presenter.present(factory.checklist(id: 'check', text: 'Done')),
      onChecklistChanged: (value) => changed = value,
    ));

    await tester.tap(find.byType(Checkbox));
    expect(changed, isTrue);
  });

  testWidgets('renders and opens Object references', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(
      presenter.present(factory.objectReference(id: 'ref', objectId: 42)),
      onObjectReferenceTap: () => tapped = true,
    ));

    expect(find.text('Object #42'), findsOneWidget);
    await tester.tap(find.text('Object #42'));
    expect(tapped, isTrue);
  });

  testWidgets('renders unknown blocks without flattening them', (tester) async {
    const unknown = ObjectBodyBlockPresentation(
      kind: ObjectBodyBlockPresentationKind.unknown,
      block: ObjectBodyBlock(id: 'future', type: 'futureWidget'),
    );
    await tester.pumpWidget(host(unknown));
    expect(find.text('Unsupported block: futureWidget'), findsOneWidget);
  });
}
