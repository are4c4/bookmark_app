import 'package:bookmark_app/features/object/presentation/widgets/object_body_reference_picker_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('forwards reference result presentation and tap callback', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectBodyReferencePickerResultTile(
            leadingText: 'P',
            title: 'Ada Lovelace',
            subtitle: 'Person',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('P'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Person'), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    expect(tapped, isTrue);
  });
}
