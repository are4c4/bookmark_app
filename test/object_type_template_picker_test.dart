import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/widgets/object_type_template_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('template picker lists empty database and built-in templates', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ObjectTypeTemplatePickerDialog())),
    );

    expect(find.text('空のデータベース'), findsOneWidget);
    for (final template in ObjectTypeTemplateStore.templates) {
      expect(find.text(template.name), findsOneWidget);
      expect(find.text(template.description), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('template search matches names descriptions and properties',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ObjectTypeTemplatePickerDialog())),
    );

    final search = find.byKey(const ValueKey('object-type-template-search'));
    await tester.enterText(search, '植物');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('object-type-template-plant')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-type-template-paper')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('object-type-template-book')),
      findsNothing,
    );
    expect(find.text('空のデータベース'), findsOneWidget);

    await tester.enterText(search, 'タグ');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('object-type-template-paper')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-type-template-plant')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-type-template-book')),
      findsNothing,
    );

    await tester.enterText(search, 'url');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('object-type-template-book')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-type-template-person')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-type-template-note')),
      findsOneWidget,
    );
  });

  testWidgets('template search fails soft and can be cleared', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ObjectTypeTemplatePickerDialog())),
    );

    final search = find.byKey(const ValueKey('object-type-template-search'));
    await tester.enterText(search, '存在しないテンプレート');
    await tester.pump();

    expect(
      find.byKey(const ValueKey('object-type-template-empty-result')),
      findsOneWidget,
    );
    expect(find.text('空のデータベース'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('object-type-template-search-clear')),
    );
    await tester.pump();
    for (final template in ObjectTypeTemplateStore.templates) {
      expect(
        find.byKey(ValueKey('object-type-template-${template.key}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('template picker returns selected template', (tester) async {
    ObjectTypeCreationChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showObjectTypeTemplatePicker(context);
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
      find.byKey(const ValueKey('object-type-template-search')),
      '評価',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('object-type-template-book')));
    await tester.pumpAndSettle();

    expect(result, isA<TemplateObjectTypeChoice>());
    expect(
      (result as TemplateObjectTypeChoice).template.key,
      'book',
    );
  });
}
