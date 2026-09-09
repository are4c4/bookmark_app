import 'package:bookmark_app/domain/object_query.dart';
import 'package:bookmark_app/widgets/object_hierarchy_match_mode_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows hierarchy labels and reports selected mode', (
    tester,
  ) async {
    var selected = ObjectHierarchyMatchMode.exact;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ObjectHierarchyMatchModeField(
              value: selected,
              onChanged: (mode) => setState(() => selected = mode),
            ),
          ),
        ),
      ),
    );

    expect(find.text('完全一致'), findsOneWidget);

    await tester.tap(find.text('完全一致'));
    await tester.pumpAndSettle();
    expect(find.text('配下を含む'), findsOneWidget);
    expect(find.text('配下のみ'), findsOneWidget);
    expect(find.text('枝を除外'), findsOneWidget);

    await tester.tap(find.text('配下を含む'));
    await tester.pumpAndSettle();

    expect(selected, ObjectHierarchyMatchMode.isOrBelow);
    expect(find.text('配下を含む'), findsOneWidget);
  });
}
