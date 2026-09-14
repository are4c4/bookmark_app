import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/features/database/presentation/widgets/database_property_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'hidden Database Property does not render retained View value',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DatabasePropertyValueView(
              property: GenericPropertyRecord(
                id: 7,
                databaseId: 3,
                name: 'File',
                type: 'file',
                config: <String, dynamic>{
                  'system': true,
                  'hidden': true,
                },
                sortOrder: 0,
              ),
              value: '/managed/internal/path.jpg',
            ),
          ),
        ),
      );

      expect(find.text('/managed/internal/path.jpg'), findsNothing);
    },
  );

  testWidgets('visible Database Property still renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DatabasePropertyValueView(
            property: GenericPropertyRecord(
              id: 8,
              databaseId: 3,
              name: 'Status',
              type: 'text',
              config: <String, dynamic>{},
              sortOrder: 1,
            ),
            value: 'Visible value',
          ),
        ),
      ),
    );

    expect(find.text('Visible value'), findsOneWidget);
  });
}
