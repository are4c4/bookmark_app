import 'package:bookmark_app/features/database/presentation/widgets/property_add_popover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required RevealExistingProperty onRevealExisting,
    required CreatePropertyFromPopover onCreateNew,
    List<PropertyAddTypeOption> propertyTypes = const [
      PropertyAddTypeOption(
        key: 'text',
        label: 'テキスト',
        icon: Icons.text_fields,
      ),
      PropertyAddTypeOption(
        key: 'number',
        label: '数値',
        icon: Icons.numbers,
      ),
    ],
    List<PropertyAddRelationTarget> relationTargets = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: PropertyAddPopover(
            hiddenProperties: const [
              PropertyAddCandidate(id: 1, name: '説明', type: 'text'),
              PropertyAddCandidate(id: 2, name: '評価', type: 'rating'),
            ],
            propertyTypes: propertyTypes,
            relationTargets: relationTargets,
            onRevealExisting: onRevealExisting,
            onCreateNew: onCreateNew,
          ),
        ),
      ),
    );
  }

  testWidgets('searches and reveals one hidden Property directly', (tester) async {
    PropertyAddCandidate? revealed;

    await tester.pumpWidget(
      host(
        onRevealExisting: (property) => revealed = property,
        onCreateNew: (_) {},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('property-add-popover-button')));
    await tester.pumpAndSettle();

    expect(find.text('非表示のプロパティ'), findsOneWidget);
    expect(find.byKey(const ValueKey('property-add-existing-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('property-add-existing-2')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('property-add-search')),
      '評価',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('property-add-existing-1')), findsNothing);
    expect(find.byKey(const ValueKey('property-add-existing-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('property-add-existing-2')));
    await tester.pumpAndSettle();

    expect(revealed?.id, 2);
    expect(find.byKey(const ValueKey('property-add-search')), findsNothing);
  });

  testWidgets('creates a new Property from the same anchored flow', (tester) async {
    PropertyCreateRequest? created;

    await tester.pumpWidget(
      host(
        onRevealExisting: (_) {},
        onCreateNew: (request) => created = request,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('property-add-popover-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('property-add-create-new')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('property-add-create-name')),
      '価格',
    );
    await tester.tap(find.byKey(const ValueKey('property-add-type-number')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('property-add-create-submit')));
    await tester.pumpAndSettle();

    expect(created?.name, '価格');
    expect(created?.type, 'number');
    expect(created?.relationTargetObjectTypeId, isNull);
    expect(find.byKey(const ValueKey('property-add-create-name')), findsNothing);
  });

  testWidgets(
      'Relation creation searches targets, distinguishes kinds, and requires explicit cardinality',
      (tester) async {
    PropertyCreateRequest? created;

    await tester.pumpWidget(
      host(
        propertyTypes: const [
          PropertyAddTypeOption(
            key: 'text',
            label: 'テキスト',
            icon: Icons.text_fields,
          ),
          PropertyAddTypeOption(
            key: 'relation',
            label: 'リレーション',
            icon: Icons.swap_horiz,
          ),
        ],
        relationTargets: const [
          PropertyAddRelationTarget(
            id: 10,
            name: 'Image',
            icon: '🖼️',
            isBuiltIn: true,
          ),
          PropertyAddRelationTarget(
            id: 11,
            name: 'Project',
            icon: '📁',
            isBuiltIn: false,
          ),
        ],
        onRevealExisting: (_) {},
        onCreateNew: (request) => created = request,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('property-add-popover-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('property-add-create-new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('property-add-create-name')),
      'Cover',
    );
    await tester.tap(find.byKey(const ValueKey('property-add-type-relation')));
    await tester.pumpAndSettle();

    expect(find.text('組み込み ObjectType'), findsOneWidget);
    expect(find.text('カスタム ObjectType'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.byKey(const ValueKey('property-add-create-submit')),
      ).onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('property-add-relation-target-search')),
      'image',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('property-add-relation-target-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('property-add-relation-target-11')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('property-add-relation-target-10')),
    );
    await tester.pump();
    await tester.tap(find.text('single'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('property-add-create-submit')));
    await tester.pumpAndSettle();

    expect(created?.name, 'Cover');
    expect(created?.type, 'relation');
    expect(created?.relationTargetObjectTypeId, 10);
    expect(created?.relationMultiple, isFalse);
  });
}
