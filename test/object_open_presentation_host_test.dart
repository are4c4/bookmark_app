import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:bookmark_app/features/object/presentation/object_open_presentation_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const host = ObjectOpenPresentationHost();

  testWidgets('side peek delegates to contextual pane without navigation',
      (tester) async {
    var sidePeekCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => host.open(
              context: context,
              mode: ObjectOpenMode.sidePeek,
              onSidePeek: () => sidePeekCount += 1,
              detailBuilder: (_) => const Text('detail-content'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(sidePeekCount, 1);
    expect(find.text('detail-content'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('center peek presents the shared detail builder in a dialog',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => host.open(
              context: context,
              mode: ObjectOpenMode.centerPeek,
              onSidePeek: () {},
              detailBuilder: (_) => const Material(
                child: Center(child: Text('detail-content')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('detail-content'), findsOneWidget);
  });

  testWidgets('full page pushes the shared detail builder as a route',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => host.open(
              context: context,
              mode: ObjectOpenMode.fullPage,
              onSidePeek: () {},
              detailBuilder: (_) => const Scaffold(
                body: Center(child: Text('detail-content')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('detail-content'), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });
}
