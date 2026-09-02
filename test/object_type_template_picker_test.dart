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
    await tester.tap(find.text('書籍'));
    await tester.pumpAndSettle();

    expect(result, isA<TemplateObjectTypeChoice>());
    expect(
      (result as TemplateObjectTypeChoice).template.key,
      'book',
    );
  });
}
