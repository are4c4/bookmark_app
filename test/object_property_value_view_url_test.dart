import 'package:bookmark_app/domain/object_detail_property_presentation.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_property_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const urlProperty = ObjectPropertyDefinition(
    id: 1,
    objectTypeId: 1,
    name: 'URL',
    type: ObjectPropertyType.url,
    sortOrder: 0,
  );

  Widget host(
    String value, {
    ObjectPropertyUrlOpener? opener,
  }) => MaterialApp(
        home: Scaffold(
          body: ObjectPropertyValueView(
            presentation: ObjectDetailPropertyPresentation(
              property: urlProperty,
              value: value,
              displayText: value,
              isHidden: false,
            ),
            urlOpener: opener,
          ),
        ),
      );

  testWidgets('http URL property opens through the injected external opener',
      (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      host(
        'https://example.com/article?x=1',
        opener: (uri) async {
          opened = uri;
          return true;
        },
      ),
    );

    final text = find.text('https://example.com/article?x=1');
    expect(text, findsOneWidget);
    final rendered = tester.widget<Text>(text);
    expect(rendered.style?.decoration, TextDecoration.underline);
    expect(find.byType(GestureDetector), findsWidgets);

    await tester.tap(text);
    await tester.pump();

    expect(opened, Uri.parse('https://example.com/article?x=1'));
  });

  testWidgets('non-http URL-like values stay non-interactive', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        'javascript:alert(1)',
        opener: (uri) async {
          calls += 1;
          return true;
        },
      ),
    );

    final text = find.text('javascript:alert(1)');
    expect(text, findsOneWidget);
    final rendered = tester.widget<Text>(text);
    expect(rendered.style?.decoration, isNull);

    await tester.tap(text);
    await tester.pump();
    expect(calls, 0);
  });
}
