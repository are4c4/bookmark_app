import 'dart:ui' show PointerDeviceKind;

import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_actions.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const document = ObjectBodyDocument(
    blocks: [
      ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph, text: 'A'),
      ObjectBodyBlock(id: 'b', type: ObjectBodyBlockType.paragraph, text: 'B'),
      ObjectBodyBlock(id: 'c', type: ObjectBodyBlockType.paragraph, text: 'C'),
    ],
  );

  Widget desktopHost({
    ObjectBodyBlockActionsBuilder? blockActionsBuilder,
    ObjectBodyBlockReorderHandler? onBlockReorder,
    void Function(ObjectBodyBlock block, String text)? onTextChanged,
  }) => MaterialApp(
    theme: ThemeData(platform: TargetPlatform.macOS),
    home: Scaffold(
      body: ObjectBodyDocumentView(
        document: document,
        onTextChanged: onTextChanged,
        onBlockReorder: onBlockReorder,
        blockActionsBuilder: blockActionsBuilder,
      ),
    ),
  );

  testWidgets('desktop actions stay hidden idle and reveal on hover or focus', (
    tester,
  ) async {
    final seen = <String, ObjectBodyBlockPosition>{};
    await tester.pumpWidget(
      desktopHost(
        onTextChanged: (_, _) {},
        blockActionsBuilder: (context, block, position) {
          seen[block.id] = position;
          return Text('actions-${block.id}');
        },
      ),
    );

    expect(find.text('actions-a'), findsNothing);
    expect(find.text('actions-b'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('object-body-entry-a'))),
    );
    await tester.pump();

    expect(find.text('actions-a'), findsOneWidget);
    expect(find.text('actions-b'), findsNothing);
    expect(seen['a']!.canMoveUp, isFalse);
    expect(seen['a']!.canMoveDown, isTrue);

    await mouse.moveTo(const Offset(700, 700));
    await tester.tap(find.byKey(const ValueKey('body-text-b')));
    await tester.pump();

    expect(find.text('actions-a'), findsNothing);
    expect(find.text('actions-b'), findsOneWidget);
    expect(seen['b']!.canMoveUp, isTrue);
    expect(seen['b']!.canMoveDown, isTrue);
  });

  testWidgets('touch keeps a discoverable explicit action affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: ObjectBodyDocumentView(
            document: document,
            blockActionsBuilder: (context, block, position) =>
                Text('actions-${block.id}'),
          ),
        ),
      ),
    );

    expect(find.text('actions-a'), findsNothing);
    expect(
      find.byKey(const ValueKey('body-block-touch-actions-a')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('body-block-touch-actions-a')));
    await tester.pump();

    expect(find.text('actions-a'), findsOneWidget);
  });

  testWidgets(
    'reorder normalizes framework indices and preserves block identity',
    (tester) async {
      ObjectBodyBlock? reordered;
      int? toIndex;
      await tester.pumpWidget(
        desktopHost(
          onBlockReorder: (block, index) async {
            reordered = block;
            toIndex = index;
          },
          blockActionsBuilder: (context, block, position) =>
              Text('actions-${block.id}'),
        ),
      );

      final reorderable = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderable.onReorder(0, 3);
      await tester.pump();

      expect(reordered?.id, 'a');
      expect(reordered?.text, 'A');
      expect(toIndex, 2);
    },
  );

  testWidgets('document remains action-free when no builder is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ObjectBodyDocumentView(document: document)),
      ),
    );

    expect(find.byKey(const ValueKey('object-body-block-a')), findsOneWidget);
    expect(find.textContaining('actions-'), findsNothing);
    expect(find.byType(ReorderableListView), findsNothing);
  });
}
