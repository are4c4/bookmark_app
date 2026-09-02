import 'package:bookmark_app/domain/object_body_block_actions.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_insert_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('insert menu exposes generic block kinds and returns selection', (tester) async {
    ObjectBodyInsertKind? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ObjectBodyInsertMenuButton(
          onSelected: (kind) => selected = kind,
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('テキスト'), findsOneWidget);
    expect(find.text('見出し 1'), findsOneWidget);
    expect(find.text('チェックリスト'), findsOneWidget);
    expect(find.text('区切り線'), findsOneWidget);

    await tester.tap(find.text('番号付きリスト'));
    await tester.pumpAndSettle();
    expect(selected, ObjectBodyInsertKind.numberedListItem);
  });

  test('labels stay stable for all insert kinds', () {
    final labels = ObjectBodyInsertKind.values
        .map(ObjectBodyInsertMenuButton.labelFor)
        .toSet();
    expect(labels, hasLength(ObjectBodyInsertKind.values.length));
    expect(ObjectBodyInsertMenuButton.labelFor(ObjectBodyInsertKind.callout), 'コールアウト');
  });
}
