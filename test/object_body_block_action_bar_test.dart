import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_actions.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_body_reference_insert.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_block_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const block = ObjectBodyBlock(
    id: 'b',
    type: ObjectBodyBlockType.paragraph,
    text: 'Body',
  );

  Widget host({
    required ObjectBodyBlockPosition position,
    VoidCallback? onMoveUp,
    VoidCallback? onMoveDown,
    VoidCallback? onDuplicate,
    VoidCallback? onDelete,
    ValueChanged<ObjectBodyInsertKind>? onInsertAfter,
    ValueChanged<ObjectBodyReferenceInsertKind>? onInsertReferenceAfter,
    List<ObjectBodyReferenceInsertKind> referenceInsertKinds =
        ObjectBodyReferenceInsertKind.values,
  }) => MaterialApp(
        home: Scaffold(
          body: ObjectBodyBlockActionBar(
            block: block,
            position: position,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
            onInsertAfter: onInsertAfter,
            onInsertReferenceAfter: onInsertReferenceAfter,
            referenceInsertKinds: referenceInsertKinds,
          ),
        ),
      );

  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('body-block-more-b')));
    await tester.pumpAndSettle();
  }

  testWidgets('movement actions are contextual and respect block boundaries',
      (tester) async {
    var up = 0;
    var down = 0;
    await tester.pumpWidget(host(
      position: const ObjectBodyBlockPosition(index: 0, count: 2),
      onMoveUp: () => up++,
      onMoveDown: () => down++,
    ));

    expect(find.byKey(const ValueKey('body-block-more-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('body-block-move-up-b')), findsNothing);
    expect(find.byKey(const ValueKey('body-block-move-down-b')), findsNothing);

    await openMore(tester);

    final moveUp = tester.widget<PopupMenuItem<Object?>>(
      find.byKey(const ValueKey('body-block-move-up-b')),
    );
    expect(moveUp.enabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('body-block-move-down-b')));
    await tester.pumpAndSettle();

    expect(up, 0);
    expect(down, 1);
  });

  testWidgets('delete is contextual while insert stays one click away',
      (tester) async {
    var deleted = 0;
    ObjectBodyInsertKind? inserted;
    await tester.pumpWidget(host(
      position: const ObjectBodyBlockPosition(index: 1, count: 3),
      onDelete: () => deleted++,
      onInsertAfter: (kind) => inserted = kind,
    ));

    expect(find.byKey(const ValueKey('body-block-delete-b')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('body-block-insert-after-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('チェックリスト'));
    await tester.pumpAndSettle();
    expect(inserted, ObjectBodyInsertKind.checklist);

    await openMore(tester);
    await tester.tap(find.byKey(const ValueKey('body-block-delete-b')));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('duplicate action is exposed in the contextual menu only',
      (tester) async {
    var duplicated = 0;
    await tester.pumpWidget(host(
      position: const ObjectBodyBlockPosition(index: 0, count: 1),
      onDuplicate: () => duplicated++,
    ));

    expect(find.byKey(const ValueKey('body-block-duplicate-b')), findsNothing);
    await openMore(tester);
    await tester.tap(find.byKey(const ValueKey('body-block-duplicate-b')));
    await tester.pumpAndSettle();
    expect(duplicated, 1);
  });

  testWidgets('reference insert starts explicit target-selection flow',
      (tester) async {
    ObjectBodyReferenceInsertKind? selected;
    await tester.pumpWidget(host(
      position: const ObjectBodyBlockPosition(index: 0, count: 1),
      onInsertReferenceAfter: (kind) => selected = kind,
    ));

    await tester.tap(
      find.byKey(const ValueKey('body-block-insert-reference-after-b')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Object を参照'));
    await tester.pumpAndSettle();

    expect(selected, ObjectBodyReferenceInsertKind.object);
  });

  testWidgets('reference insert can expose only host-supported kinds',
      (tester) async {
    await tester.pumpWidget(host(
      position: const ObjectBodyBlockPosition(index: 0, count: 1),
      onInsertReferenceAfter: (_) {},
      referenceInsertKinds: const [ObjectBodyReferenceInsertKind.object],
    ));

    await tester.tap(
      find.byKey(const ValueKey('body-block-insert-reference-after-b')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Object を参照'), findsOneWidget);
    expect(find.text('Database / View を埋め込む'), findsNothing);
    expect(find.text('画像を埋め込む'), findsNothing);
    expect(find.text('ファイルを埋め込む'), findsNothing);
  });

  testWidgets('optional action controls are omitted without callbacks',
      (tester) async {
    await tester.pumpWidget(host(
      position: const ObjectBodyBlockPosition(index: 0, count: 1),
    ));

    expect(find.byKey(const ValueKey('body-block-insert-after-b')), findsNothing);
    expect(
      find.byKey(const ValueKey('body-block-insert-reference-after-b')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('body-block-more-b')), findsNothing);
  });
}
