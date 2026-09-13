import 'package:bookmark_app/domain/object_identity_search.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:bookmark_app/widgets/object_query_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const relationProperty = ObjectPropertyDefinition(
  id: 20,
  objectTypeId: 1,
  name: '著者',
  type: ObjectPropertyType.objectRelation,
  sortOrder: 0,
  config: <String, dynamic>{'targetObjectTypeId': 2, 'multiple': true},
);

const personType = AppObjectType(
  id: 2,
  workspaceId: 1,
  name: 'Person',
  icon: '👤',
  kind: ObjectTypeKind.system,
  sortOrder: 0,
);

ObjectIdentitySearchResult candidate(int id, String title) =>
    ObjectIdentitySearchResult(
      object: AppObject(
        id: id,
        objectTypeId: 2,
        title: title,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      objectType: personType,
      aliases: const <String>[],
    );

void main() {
  testWidgets(
    'authors Relation filter by title while returning canonical ids',
    (tester) async {
      ObjectQueryDraft? result;
      final candidates = <ObjectIdentitySearchResult>[
        candidate(7, '今野忍'),
        candidate(8, '佐藤花子'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showObjectQueryDialog(
                    context,
                    properties: const <ObjectPropertyDefinition>[
                      relationProperty,
                    ],
                    initialFilters: const <ObjectFilterRule>[
                      ObjectFilterRule(
                        propertyId: 20,
                        operator: ObjectFilterOperator.containsAny,
                        value: <int>[7],
                      ),
                    ],
                    relationCandidateSearch: (property, query) async {
                      expect(property.id, 20);
                      final normalized = query.trim();
                      return candidates
                          .where(
                            (entry) =>
                                normalized.isEmpty ||
                                entry.canonicalTitle.contains(normalized),
                          )
                          .toList(growable: false);
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

      expect(find.text('今野忍'), findsWidgets);
      expect(find.text('Object IDをカンマ区切り'), findsNothing);

      final selectedChip = tester.widget<InputChip>(
        find.byKey(const ValueKey('relation-filter-selected-7')),
      );
      selectedChip.onDeleted!();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('relation-filter-candidate-8')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('適用'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.filters, hasLength(1));
      expect(result!.filters.single.propertyId, 20);
      expect(result!.filters.single.operator, ObjectFilterOperator.containsAny);
      expect(result!.filters.single.value, <int>[8]);
    },
  );

  testWidgets('fails closed instead of exposing raw ids without a provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectQueryDialog(
            properties: <ObjectPropertyDefinition>[relationProperty],
            initialFilters: <ObjectFilterRule>[
              ObjectFilterRule(
                propertyId: 20,
                operator: ObjectFilterOperator.containsAny,
                value: <int>[7],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Relation候補を読み込めません'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('Object ID'), findsNothing);
  });
}
