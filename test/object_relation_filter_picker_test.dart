import 'package:bookmark_app/domain/object_identity_search.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/object_relation_filter_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _type = AppObjectType(
  id: 10,
  workspaceId: 1,
  name: 'Person',
  icon: '👤',
  kind: ObjectTypeKind.system,
  sortOrder: 0,
);

ObjectIdentitySearchResult _candidate(
  int id,
  String title, {
  List<String> aliases = const [],
  String? matchedAlias,
}) =>
    ObjectIdentitySearchResult(
      object: AppObject(
        id: id,
        objectTypeId: _type.id,
        title: title,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      objectType: _type,
      aliases: aliases,
      matchedAlias: matchedAlias,
    );

void main() {
  testWidgets('shows canonical titles, preserves ids and exposes missing targets', (
    tester,
  ) async {
    var selected = <int>[2, 99];
    late StateSetter setHostState;
    final candidates = <ObjectIdentitySearchResult>[
      _candidate(1, 'Alice'),
      _candidate(2, 'Bob', aliases: const ['Robert']),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return ObjectRelationFilterPicker(
                selectedObjectIds: selected,
                searchCandidates: (query) async {
                  final normalized = query.trim().toLowerCase();
                  if (normalized.isEmpty) return candidates;
                  return candidates
                      .where(
                        (candidate) =>
                            candidate.canonicalTitle.toLowerCase().contains(
                                  normalized,
                                ) ||
                            candidate.aliases.any(
                              (alias) => alias.toLowerCase().contains(normalized),
                            ),
                      )
                      .toList(growable: false);
                },
                onChanged: (next) => setHostState(() => selected = next),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('不明なObject #99'), findsOneWidget);
    expect(find.textContaining('Object ID'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('relation-filter-search')),
      'Alice',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relation-filter-candidate-1')));
    await tester.pumpAndSettle();
    expect(selected, <int>[2, 99, 1]);

    await tester.tap(find.byKey(const ValueKey('relation-filter-selected-99')));
    await tester.pumpAndSettle();
    // Tapping the chip itself does not remove it; removal remains explicit via
    // the chip delete affordance so accidental target changes are avoided.
    expect(selected, contains(99));
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('relation-filter-selected-99')),
        matching: find.byIcon(Icons.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, <int>[2, 1]);
  });

  testWidgets('keyboard arrows, Enter and Escape operate on search candidates', (
    tester,
  ) async {
    var selected = <int>[];
    late StateSetter setHostState;
    final candidates = <ObjectIdentitySearchResult>[
      _candidate(1, 'Alice'),
      _candidate(2, 'Bob'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return ObjectRelationFilterPicker(
                selectedObjectIds: selected,
                searchCandidates: (_) async => candidates,
                onChanged: (next) => setHostState(() => selected = next),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('relation-filter-search')));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, <int>[2]);

    await tester.enterText(
      find.byKey(const ValueKey('relation-filter-search')),
      'Bob',
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('relation-filter-search')),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('search failure is visible and does not rewrite selected ids', (
    tester,
  ) async {
    final selected = <int>[7];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectRelationFilterPicker(
            selectedObjectIds: selected,
            searchCandidates: (_) async => throw StateError('boom'),
            onChanged: (_) => fail('failure must not mutate selection'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('relation-filter-search-error')),
      findsOneWidget,
    );
    expect(find.text('不明なObject #7'), findsOneWidget);
  });
}
