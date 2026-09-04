import 'package:bookmark_app/features/object/presentation/widgets/object_alias_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('alias editor adds and removes alternate names', (tester) async {
    String? added;
    String? removed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectAliasEditor(
            aliases: const ['漱石'],
            onAdd: (alias) async => added = alias,
            onRemove: (alias) async => removed = alias,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('object-alias-chip:漱石')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object-alias-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('object-alias-add-field')),
      '  夏目金之助  ',
    );
    await tester.tap(find.byKey(const ValueKey('object-alias-add-save')));
    await tester.pumpAndSettle();
    expect(added, '夏目金之助');

    final chip = tester.widget<InputChip>(
      find.byKey(const ValueKey('object-alias-chip:漱石')),
    );
    expect(chip.onDeleted, isNotNull);
    chip.onDeleted!.call();
    await tester.pump();
    expect(removed, '漱石');
  });

  testWidgets('read-only alias editor hides mutation affordances', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectAliasEditor(aliases: ['Natsume Soseki']),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('object-alias-add-button')), findsNothing);
    final chip = tester.widget<InputChip>(
      find.byKey(const ValueKey('object-alias-chip:Natsume Soseki')),
    );
    expect(chip.onDeleted, isNull);
  });
}
