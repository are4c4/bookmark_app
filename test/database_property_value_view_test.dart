import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/features/database/presentation/widgets/database_property_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GenericPropertyRecord property(String type) => GenericPropertyRecord(
      id: 7,
      databaseId: 3,
      name: type,
      type: type,
      config: const <String, dynamic>{},
      sortOrder: 0,
    );

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('Database MultiSelect uses shared chips', (tester) async {
    await tester.pumpWidget(
      host(
        DatabasePropertyValueView(
          property: property('multiSelect'),
          value: const <String>['札幌', '旅行'],
        ),
      ),
    );

    expect(find.byType(Chip), findsNWidgets(2));
    expect(find.text('札幌'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('札幌, 旅行'), findsNothing);
  });

  testWidgets('Database Relation renders canonical labels, never ids',
      (tester) async {
    await tester.pumpWidget(
      host(
        DatabasePropertyValueView(
          property: property('relation'),
          value: const <int>[41, 42],
          relationLabels: const <String>['Alice', 'Bob'],
        ),
      ),
    );

    expect(find.byType(Chip), findsNWidgets(2));
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('41'), findsNothing);
    expect(find.text('42'), findsNothing);
  });
}
