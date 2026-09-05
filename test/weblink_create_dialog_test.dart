import 'package:bookmark_app/features/database/presentation/widgets/weblink_create_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requires URL and returns trimmed URL plus optional title', (tester) async {
    WeblinkCreateInput? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showWeblinkCreateDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('weblink-create-submit')),
    );
    expect(submit.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('weblink-create-url')),
      '  https://example.com/guide  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('weblink-create-title')),
      '  Guide  ',
    );
    await tester.pump();

    final enabled = tester.widget<FilledButton>(
      find.byKey(const ValueKey('weblink-create-submit')),
    );
    expect(enabled.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('weblink-create-submit')));
    await tester.pumpAndSettle();

    expect(result?.url, 'https://example.com/guide');
    expect(result?.title, 'Guide');
  });

  testWidgets('empty optional title returns null', (tester) async {
    WeblinkCreateInput? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showWeblinkCreateDialog(context);
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
      find.byKey(const ValueKey('weblink-create-url')),
      'https://example.com/',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('weblink-create-submit')));
    await tester.pumpAndSettle();

    expect(result?.url, 'https://example.com/');
    expect(result?.title, isNull);
  });
}
