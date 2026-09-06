import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_schema_evolution_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/relation_property_schema_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RelationSchemaEvolutionService _evolution(
  GenericDatabaseStore genericStore,
  ObjectStore objectStore,
) {
  final bidirectional = BidirectionalRelationStore(
    genericStore: genericStore,
    objectStore: objectStore,
  );
  return RelationSchemaEvolutionService(
    objectStore: objectStore,
    genericStore: genericStore,
    relationMutations: RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectional,
      genericStore: genericStore,
    ),
  );
}

Widget _host({required VoidCallback onOpen}) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (_) => TextButton(
            onPressed: onOpen,
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('target edit previews impact then applies through canonical service',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final evolution = _evolution(genericStore, objectStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final companyTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Company',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((candidate) => candidate.id == propertyId);

    ObjectPropertyDefinition? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showRelationPropertySchemaEditor(
                  context: context,
                  property: property,
                  objectStore: objectStore,
                  schemaEvolution: evolution,
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
    expect(find.text('Relation Propertyを編集'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('relation-property-target-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Company').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('変更内容を確認'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('relation-schema-target-change')), findsOneWidget);
    expect(find.textContaining('Person'), findsWidgets);
    expect(find.textContaining('Company'), findsWidgets);

    await tester.tap(find.text('変更を続ける'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.id, propertyId);
    expect(result!.targetObjectTypeId, companyTypeId);
    expect(result!.allowsMultipleRelations, isTrue);
  });

  testWidgets('multi to single requires explicit remaining target then applies',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectional = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectional,
      genericStore: genericStore,
    );
    final evolution = RelationSchemaEvolutionService(
      objectStore: objectStore,
      genericStore: genericStore,
      relationMutations: mutations,
    );

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Authors',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final property = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((candidate) => candidate.id == propertyId);
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book A',
    );
    final personA = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person A',
    );
    final personB = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person B',
    );
    await mutations.setRelation(
      objectId: bookId,
      property: property,
      targetObjectIds: [personA, personB],
    );

    ObjectPropertyDefinition? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showRelationPropertySchemaEditor(
                  context: context,
                  property: property,
                  objectStore: objectStore,
                  schemaEvolution: evolution,
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
    await tester.tap(find.byKey(const ValueKey('relation-property-multiple')));
    await tester.pumpAndSettle();
    expect(find.text('single'), findsOneWidget);
    await tester.tap(find.text('変更内容を確認'));
    await tester.pumpAndSettle();

    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('relation-schema-confirm')),
    );
    expect(confirm.onPressed, isNull);

    await tester.tap(
      find.byKey(ValueKey('relation-schema-choice-$bookId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Person B').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('relation-schema-confirm')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('変更を続ける'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.allowsMultipleRelations, isFalse);
    final book = (await objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[propertyId]).objectIds,
      [personB],
    );
  });
}
