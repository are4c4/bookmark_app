import 'package:bookmark_app/features/object/presentation/widgets/object_body_reference_picker_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('encodes the shared reference-picker search presentation', (
    tester,
  ) async {
    var query = '';
    const fieldKey = ValueKey('shared-reference-picker-search');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectBodyReferencePickerSearchField(
            fieldKey: fieldKey,
            hintText: 'Search references',
            onChanged: (value) => query = value,
          ),
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(find.byKey(fieldKey));
    expect(field.autofocus, isTrue);
    expect(field.decoration?.hintText, 'Search references');
    expect(find.byIcon(Icons.search), findsOneWidget);

    await tester.enterText(find.byKey(fieldKey), 'Person');
    expect(query, 'Person');
  });
}
