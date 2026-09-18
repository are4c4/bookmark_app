import 'dart:async';

import 'package:bookmark_app/features/shell/presentation/widgets/unified_command_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const home = UnifiedCommandPaletteItem(
    keyName: 'destination:home',
    kind: UnifiedCommandPaletteItemKind.destination,
    label: 'ホーム',
    icon: Icons.home_outlined,
    navigationIndex: 12,
  );
  const search = UnifiedCommandPaletteItem(
    keyName: 'destination:search',
    kind: UnifiedCommandPaletteItemKind.destination,
    label: '全文検索を開く',
    icon: Icons.search,
    navigationIndex: 1,
    recoveryOnSearchFailure: true,
  );
  const database = UnifiedCommandPaletteItem(
    keyName: 'database:7',
    kind: UnifiedCommandPaletteItemKind.database,
    label: 'Papers',
    iconText: '📄',
    databaseId: 7,
  );

  testWidgets('arrow keys and Enter activate the highlighted static item', (
    tester,
  ) async {
    UnifiedCommandPaletteItem? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selected = await showUnifiedCommandPalette(
                  context: context,
                  staticItems: const <UnifiedCommandPaletteItem>[home, search],
                  searchObjects: (_) async =>
                      const <UnifiedCommandPaletteItem>[],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selected?.navigationIndex, 1);
    expect(find.text('コマンドパレット'), findsNothing);
  });

  testWidgets('Escape closes without selecting an item', (tester) async {
    UnifiedCommandPaletteItem? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selected = await showUnifiedCommandPalette(
                  context: context,
                  staticItems: const <UnifiedCommandPaletteItem>[home],
                  searchObjects: (_) async =>
                      const <UnifiedCommandPaletteItem>[],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(find.text('コマンドパレット'), findsNothing);
  });

  testWidgets('async Object results do not steal an existing selection', (
    tester,
  ) async {
    final completer = Completer<List<UnifiedCommandPaletteItem>>();
    UnifiedCommandPaletteItem? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selected = await showUnifiedCommandPalette(
                  context: context,
                  staticItems: const <UnifiedCommandPaletteItem>[database],
                  searchObjects: (_) => completer.future,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final query = find.byKey(
      const ValueKey<String>('unified-command-palette-query'),
    );
    await tester.enterText(query, 'paper');
    await tester.pump(const Duration(milliseconds: 180));

    completer.complete(const <UnifiedCommandPaletteItem>[
      UnifiedCommandPaletteItem(
        keyName: 'object:42',
        kind: UnifiedCommandPaletteItemKind.object,
        label: 'Paper object',
        subtitle: 'Paper',
        objectId: 42,
      ),
    ]);
    await tester.pumpAndSettle();

    final databaseTile = tester.widget<ListTile>(
      find.byKey(
        const ValueKey<String>('unified-command-palette-item-database:7'),
      ),
    );
    expect(databaseTile.selected, isTrue);
    expect(find.text('Paper object'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected?.databaseId, 7);
  });

  testWidgets(
    'async Recent arrival preserves selection and hides while querying',
    (tester) async {
      final recentCompleter = Completer<List<UnifiedCommandPaletteItem>>();
      UnifiedCommandPaletteItem? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  selected = await showUnifiedCommandPalette(
                    context: context,
                    staticItems: const <UnifiedCommandPaletteItem>[
                      home,
                      database,
                    ],
                    searchObjects: (_) async =>
                        const <UnifiedCommandPaletteItem>[],
                    loadRecentObjects: () => recentCompleter.future,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      recentCompleter.complete(const <UnifiedCommandPaletteItem>[
        UnifiedCommandPaletteItem(
          keyName: 'recent-object:42',
          kind: UnifiedCommandPaletteItemKind.object,
          label: 'Recent algebra note',
          subtitle: 'Note',
          objectId: 42,
          groupLabel: '最近のオブジェクト',
        ),
      ]);
      await tester.pumpAndSettle();

      final databaseTile = tester.widget<ListTile>(
        find.byKey(
          const ValueKey<String>('unified-command-palette-item-database:7'),
        ),
      );
      expect(databaseTile.selected, isTrue);
      expect(find.text('最近のオブジェクト'), findsOneWidget);
      expect(find.text('Recent algebra note'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('unified-command-palette-query')),
        'paper',
      );
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();

      expect(find.text('Recent algebra note'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected?.databaseId, 7);
    },
  );

  testWidgets('Recent load failure leaves static navigation usable', (
    tester,
  ) async {
    UnifiedCommandPaletteItem? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selected = await showUnifiedCommandPalette(
                  context: context,
                  staticItems: const <UnifiedCommandPaletteItem>[home],
                  searchObjects: (_) async =>
                      const <UnifiedCommandPaletteItem>[],
                  loadRecentObjects: () async =>
                      throw StateError('recent unavailable'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('ホーム'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selected?.navigationIndex, 12);
  });

  testWidgets(
    'search failure keeps the full Search recovery action reachable',
    (tester) async {
      UnifiedCommandPaletteItem? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  selected = await showUnifiedCommandPalette(
                    context: context,
                    staticItems: const <UnifiedCommandPaletteItem>[search],
                    searchObjects: (_) async => throw StateError('unavailable'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final query = find.byKey(
        const ValueKey<String>('unified-command-palette-query'),
      );
      await tester.enterText(query, 'does-not-match-search-label');
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();

      expect(find.text('オブジェクト検索を利用できません。全文検索から再試行できます。'), findsOneWidget);
      expect(find.text('全文検索を開く'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selected?.navigationIndex, 1);
    },
  );

  testWidgets('Object results can be activated directly from the query', (
    tester,
  ) async {
    UnifiedCommandPaletteItem? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selected = await showUnifiedCommandPalette(
                  context: context,
                  staticItems: const <UnifiedCommandPaletteItem>[],
                  searchObjects: (query) async =>
                      const <UnifiedCommandPaletteItem>[
                        UnifiedCommandPaletteItem(
                          keyName: 'object:42',
                          kind: UnifiedCommandPaletteItemKind.object,
                          label: 'Algebra notes',
                          subtitle: 'Note',
                          objectId: 42,
                        ),
                      ],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('unified-command-palette-query')),
      'algebra',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.text('Algebra notes'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selected?.objectId, 42);
  });

  testWidgets(
    'query action is immediate and async Search does not steal selection',
    (tester) async {
      final searchCompleter = Completer<List<UnifiedCommandPaletteItem>>();
      UnifiedCommandPaletteItem? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  selected = await showUnifiedCommandPalette(
                    context: context,
                    staticItems: const <UnifiedCommandPaletteItem>[],
                    searchObjects: (_) => searchCompleter.future,
                    queryItems: (query) {
                      final uri = Uri.tryParse(query);
                      if (uri == null ||
                          !uri.hasAuthority ||
                          (uri.scheme != 'http' && uri.scheme != 'https')) {
                        return const <UnifiedCommandPaletteItem>[];
                      }
                      return <UnifiedCommandPaletteItem>[
                        UnifiedCommandPaletteItem(
                          keyName: 'action:capture-weblink',
                          kind: UnifiedCommandPaletteItemKind.action,
                          label: 'URLを保存',
                          actionId: 'capture-weblink',
                          actionValue: query,
                        ),
                      ];
                    },
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

      final query = find.byKey(
        const ValueKey<String>('unified-command-palette-query'),
      );
      await tester.enterText(query, 'ordinary text');
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>(
            'unified-command-palette-item-action:capture-weblink',
          ),
        ),
        findsNothing,
      );

      await tester.enterText(query, 'https://example.com/from-palette');
      await tester.pump();

      final action = find.byKey(
        const ValueKey<String>(
          'unified-command-palette-item-action:capture-weblink',
        ),
      );
      expect(action, findsOneWidget);
      expect(tester.widget<ListTile>(action).selected, isTrue);

      await tester.pump(const Duration(milliseconds: 180));
      searchCompleter.complete(const <UnifiedCommandPaletteItem>[
        UnifiedCommandPaletteItem(
          keyName: 'object:99',
          kind: UnifiedCommandPaletteItemKind.object,
          label: 'Search result',
          objectId: 99,
        ),
      ]);
      await tester.pump();
      expect(tester.widget<ListTile>(action).selected, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selected?.kind, UnifiedCommandPaletteItemKind.action);
      expect(selected?.actionId, 'capture-weblink');
      expect(selected?.actionValue, 'https://example.com/from-palette');
    },
  );
}
