import 'package:bookmark_app/data/relation_target_quick_create_policy.dart';
import 'package:bookmark_app/features/database/presentation/widgets/relation_target_quick_create_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required RelationTargetQuickCreateMode mode,
  required VoidCallback? onCreate,
}) =>
    MaterialApp(
      home: Scaffold(
        body: RelationTargetQuickCreateAction(
          mode: mode,
          onCreate: onCreate,
        ),
      ),
    );

void main() {
  testWidgets('renders mode-specific safe creation affordances', (tester) async {
    final expectations = <RelationTargetQuickCreateMode, String>{
      RelationTargetQuickCreateMode.genericObject: '新しいObjectを作成',
      RelationTargetQuickCreateMode.tag: '新しいタグを作成',
      RelationTargetQuickCreateMode.weblinkUrl: 'URLからWeblinkを追加',
      RelationTargetQuickCreateMode.managedImage: '画像をインポート',
      RelationTargetQuickCreateMode.managedFile: 'ファイルをインポート',
    };

    for (final entry in expectations.entries) {
      var invoked = 0;
      await tester.pumpWidget(
        _host(
          mode: entry.key,
          onCreate: () => invoked += 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      final action = find.byKey(
        ValueKey('relation-target-quick-create-${entry.key.name}'),
      );
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pump();
      expect(invoked, 1);
    }
  });

  testWidgets('unavailable mode never offers title-only fallback', (tester) async {
    await tester.pumpWidget(
      _host(
        mode: RelationTargetQuickCreateMode.unavailable,
        onCreate: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextButton), findsNothing);
    expect(find.textContaining('作成'), findsNothing);
    expect(find.textContaining('インポート'), findsNothing);
  });

  testWidgets('missing canonical mutation callback hides the affordance',
      (tester) async {
    await tester.pumpWidget(
      _host(
        mode: RelationTargetQuickCreateMode.weblinkUrl,
        onCreate: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextButton), findsNothing);
  });
}
