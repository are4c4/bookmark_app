import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/bidirectional_relation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = AppObjectType(
    id: 1,
    workspaceId: 1,
    name: '書籍',
    icon: '📚',
    kind: ObjectTypeKind.custom,
    sortOrder: 0,
  );
  const person = AppObjectType(
    id: 2,
    workspaceId: 1,
    name: '人物',
    icon: '👤',
    kind: ObjectTypeKind.custom,
    sortOrder: 1,
  );
  const systemTag = AppObjectType(
    id: 3,
    workspaceId: 1,
    name: 'タグ',
    icon: '🏷️',
    kind: ObjectTypeKind.system,
    sortOrder: 2,
  );

  testWidgets('system ObjectTypes are excluded from bidirectional targets',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BidirectionalRelationDialog(
            sourceType: source,
            targetTypes: [person, systemTag],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();

    expect(find.text('👤 人物'), findsOneWidget);
    expect(find.text('🏷️ タグ'), findsNothing);
  });

  testWidgets('returns names, target and multiplicity choices', (tester) async {
    BidirectionalRelationDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showBidirectionalRelationDialog(
                  context,
                  sourceType: source,
                  targetTypes: const [person],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'こちら側のプロパティ名'),
      '著者',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('👤 人物').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '関連先に作る逆側プロパティ名'),
      '著書',
    );

    final switches = find.byType(SwitchListTile);
    await tester.tap(switches.first);
    await tester.pump();

    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.sourceName, '著者');
    expect(result!.inverseName, '著書');
    expect(result!.targetObjectTypeId, 2);
    expect(result!.sourceMultiple, false);
    expect(result!.inverseMultiple, true);
  });
}
