import 'package:bookmark_app/data/database_collection_config_service.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:bookmark_app/widgets/database_collection_settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppObjectType objectType(
  int id,
  String name, {
  List<ObjectPropertyDefinition> properties = const <ObjectPropertyDefinition>[],
}) =>
    AppObjectType(
      id: id,
      workspaceId: 1,
      name: name,
      icon: '🗃️',
      kind: ObjectTypeKind.custom,
      sortOrder: id,
      properties: properties,
    );

DatabaseCollectionConfigContext config() {
  final place = objectType(
    2,
    'Place',
    properties: const <ObjectPropertyDefinition>[
      ObjectPropertyDefinition(
        id: 20,
        objectTypeId: 2,
        name: '都道府県',
        type: ObjectPropertyType.text,
        sortOrder: 0,
      ),
    ],
  );
  return DatabaseCollectionConfigContext(
    definition: const DatabaseCollectionDefinition(
      databaseId: 1,
      workspaceId: 1,
      targetObjectTypeId: 2,
      collectionFilter: <ObjectFilterRule>[
        ObjectFilterRule(
          propertyId: 20,
          operator: ObjectFilterOperator.equals,
          value: '北海道',
        ),
      ],
    ),
    targetObjectType: place,
    availableObjectTypes: <AppObjectType>[
      objectType(1, 'Collection'),
      place,
      objectType(
        3,
        'Person',
        properties: const <ObjectPropertyDefinition>[
          ObjectPropertyDefinition(
            id: 30,
            objectTypeId: 3,
            name: '名前',
            type: ObjectPropertyType.text,
            sortOrder: 0,
          ),
        ],
      ),
    ],
  );
}

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('shows current target and separate collection conditions',
      (tester) async {
    await tester.pumpWidget(
      host(DatabaseCollectionSettingsDialog(config: config())),
    );

    expect(find.text('データベースのコレクション'), findsOneWidget);
    expect(find.textContaining('Viewのフィルターとは別'), findsOneWidget);
    expect(find.text('🗃️ Place'), findsOneWidget);
    expect(find.text('1件の条件'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-collection-filters')), findsOneWidget);
  });

  testWidgets('changing target clears old target filters before save',
      (tester) async {
    DatabaseCollectionSettingsDraft? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showDatabaseCollectionSettingsDialog(
                context,
                config: config(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1件の条件'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('collection-target-object-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🗃️ Person').last);
    await tester.pumpAndSettle();

    expect(find.text('すべてのPerson Object'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-collection-settings')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.targetObjectTypeId, 3);
    expect(result!.collectionFilter, isEmpty);
  });
}
