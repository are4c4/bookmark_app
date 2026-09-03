import 'package:bookmark_app/features/object/presentation/widgets/object_body_database_view_reference_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidates = <ObjectBodyDatabaseViewReferenceCandidate>[
    ObjectBodyDatabaseViewReferenceCandidate(
      databaseId: 10,
      databaseName: '読書管理',
      databaseIcon: '📚',
    ),
    ObjectBodyDatabaseViewReferenceCandidate(
      databaseId: 10,
      databaseName: '読書管理',
      databaseIcon: '📚',
      viewId: 101,
      viewName: '読書中',
    ),
    ObjectBodyDatabaseViewReferenceCandidate(
      databaseId: 20,
      databaseName: '旅行候補',
      databaseIcon: '📍',
      viewId: 201,
      viewName: '北海道',
    ),
  ];

  testWidgets('picker returns only the explicitly selected Database or View',
      (tester) async {
    ObjectBodyDatabaseViewReferenceCandidate? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showObjectBodyDatabaseViewReferencePicker(
                  context,
                  candidates: candidates,
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
    expect(selected, isNull);
    await tester.tap(
      find.byKey(const ValueKey('body-database-view-reference-10-view-101')),
    );
    await tester.pumpAndSettle();

    expect(selected?.databaseId, 10);
    expect(selected?.viewId, 101);
    expect(selected?.viewName, '読書中');
  });

  testWidgets('picker filters by Database or View name and cancel is a no-op',
      (tester) async {
    ObjectBodyDatabaseViewReferenceCandidate? selected = candidates.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showObjectBodyDatabaseViewReferencePicker(
                  context,
                  candidates: candidates,
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
      find.byKey(const ValueKey('body-database-view-reference-search')),
      '北海道',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('body-database-view-reference-20-view-201')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('body-database-view-reference-10-view-101')),
      findsNothing,
    );
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });
}
