import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/object_board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppObject object(int id, String title) => AppObject(
      id: id,
      objectTypeId: 1,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

ObjectGroupBucket<AppObject> group(
  String key,
  String label,
  List<AppObject> items, {
  dynamic value,
}) =>
    ObjectGroupBucket<AppObject>(
      key: key,
      label: label,
      value: value,
      items: items,
      isEmptyGroup: false,
    );

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 900, height: 600, child: child)),
    );

void main() {
  testWidgets('renders columns, counts, cards and empty state', (tester) async {
    final a = object(1, 'タスクA');
    final b = object(2, 'タスクB');
    await tester.pumpWidget(
      host(
        ObjectBoardView(
          groups: [
            group('todo', '未着手', [a, b]),
            group('done', '完了', []),
          ],
          onObjectTap: (_) {},
        ),
      ),
    );

    expect(find.text('未着手'), findsOneWidget);
    expect(find.text('完了'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('タスクA'), findsOneWidget);
    expect(find.text('タスクB'), findsOneWidget);
    expect(find.text('Objectはありません'), findsOneWidget);
  });

  testWidgets('card tap returns the selected Object', (tester) async {
    final a = object(1, 'タスクA');
    AppObject? selected;
    await tester.pumpWidget(
      host(
        ObjectBoardView(
          groups: [group('todo', '未着手', [a])],
          onObjectTap: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('タスクA'));
    await tester.pump();
    expect(selected?.id, 1);
  });

  testWidgets('renders host-provided semantic card content', (tester) async {
    final a = object(1, 'タスクA');
    await tester.pumpWidget(
      host(
        ObjectBoardView(
          groups: [group('todo', '未着手', [a])],
          onObjectTap: (_) {},
          cardContentBuilder: (_) => const Chip(label: Text('重要')),
        ),
      ),
    );

    expect(find.byType(Chip), findsOneWidget);
    expect(find.text('重要'), findsOneWidget);
  });

  testWidgets('create action identifies the target group', (tester) async {
    ObjectGroupBucket<AppObject>? target;
    await tester.pumpWidget(
      host(
        ObjectBoardView(
          groups: [group('todo', '未着手', [])],
          onObjectTap: (_) {},
          onCreateInGroup: (value) async => target = value,
        ),
      ),
    );

    await tester.tap(find.text('新規Object'));
    await tester.pump();
    expect(target?.key, 'todo');
  });

  testWidgets('long press drag reports source and target groups', (tester) async {
    final a = object(1, 'タスクA');
    AppObject? moved;
    ObjectGroupBucket<AppObject>? source;
    ObjectGroupBucket<AppObject>? target;
    await tester.pumpWidget(
      host(
        ObjectBoardView(
          groups: [
            group('todo', '未着手', [a], value: 'todo'),
            group('done', '完了', [], value: 'done'),
          ],
          onObjectTap: (_) {},
          onMoveObject: (object, from, to) async {
            moved = object;
            source = from;
            target = to;
          },
        ),
      ),
    );

    final card = find.text('タスクA');
    final done = find.text('完了');
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(done));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved?.id, 1);
    expect(source?.key, 'todo');
    expect(source?.value, 'todo');
    expect(target?.key, 'done');
    expect(target?.value, 'done');
  });
}
