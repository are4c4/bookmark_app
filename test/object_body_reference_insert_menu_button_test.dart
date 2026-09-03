import 'package:bookmark_app/domain/object_body_reference_insert.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_reference_insert_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reference insert menu exposes all target-selection kinds', (
    tester,
  ) async {
    ObjectBodyReferenceInsertKind? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectBodyReferenceInsertMenuButton(
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_link));
    await tester.pumpAndSettle();

    expect(find.text('Object を参照'), findsOneWidget);
    expect(find.text('Database / View を埋め込む'), findsOneWidget);
    expect(find.text('画像を埋め込む'), findsOneWidget);
    expect(find.text('ファイルを埋め込む'), findsOneWidget);

    await tester.tap(find.text('Object を参照'));
    await tester.pumpAndSettle();
    expect(selected, ObjectBodyReferenceInsertKind.object);
  });

  testWidgets('reference insert menu can expose only host-supported kinds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectBodyReferenceInsertMenuButton(
            allowedKinds: const [
              ObjectBodyReferenceInsertKind.object,
              ObjectBodyReferenceInsertKind.databaseView,
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_link));
    await tester.pumpAndSettle();

    expect(find.text('Object を参照'), findsOneWidget);
    expect(find.text('Database / View を埋め込む'), findsOneWidget);
    expect(find.text('画像を埋め込む'), findsNothing);
    expect(find.text('ファイルを埋め込む'), findsNothing);
  });

  test('labels remain explicit about selection rather than persistence', () {
    expect(
      ObjectBodyReferenceInsertMenuButton.labelFor(
        ObjectBodyReferenceInsertKind.databaseView,
      ),
      'Database / View を埋め込む',
    );
    expect(
      ObjectBodyReferenceInsertMenuButton.labelFor(
        ObjectBodyReferenceInsertKind.image,
      ),
      '画像を埋め込む',
    );
  });
}
