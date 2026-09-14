import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_group_adapter.dart';
import 'package:bookmark_app/data/database_view_health_audit.dart';
import 'package:bookmark_app/data/database_view_query_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('healthy persisted references produce no findings', () async {
    final fixture = await _ViewAuditFixture.create();
    addTearDown(fixture.close);

    final result = await fixture.audit.run(workspaceId: fixture.workspaceId);

    expect(result.findings, isEmpty);
  });

  test('dangling Property references are classified without repair', () async {
    final fixture = await _ViewAuditFixture.create();
    addTearDown(fixture.close);

    await fixture.database.customStatement(
      'DELETE FROM generic_properties WHERE id = ?',
      [fixture.propertyId],
    );

    final result = await fixture.audit.run(workspaceId: fixture.workspaceId);
    final kinds = result.findings.map((finding) => finding.kind).toSet();

    expect(
      kinds,
      containsAll(<DatabaseViewHealthIssueKind>{
        DatabaseViewHealthIssueKind.danglingVisibleProperty,
        DatabaseViewHealthIssueKind.danglingPropertyOrder,
        DatabaseViewHealthIssueKind.danglingFilterProperty,
        DatabaseViewHealthIssueKind.danglingSortProperty,
        DatabaseViewHealthIssueKind.danglingGroupProperty,
        DatabaseViewHealthIssueKind.danglingGalleryCoverProperty,
      }),
    );
    expect(result.affectedViewIds, {fixture.viewId});
    expect(
      result.findings.where((finding) => finding.propertyId != null),
      everyElement(
        isA<DatabaseViewHealthFinding>()
            .having((finding) => finding.viewId, 'viewId', fixture.viewId)
            .having(
              (finding) => finding.databaseId,
              'databaseId',
              fixture.objectTypeId,
            )
            .having(
              (finding) => finding.objectTypeId,
              'objectTypeId',
              fixture.objectTypeId,
            )
            .having(
              (finding) => finding.propertyId,
              'propertyId',
              fixture.propertyId,
            ),
      ),
    );

    final persisted = (await fixture.viewStore.listWorkspaceViews(
      workspaceId: fixture.workspaceId,
    )).singleWhere((view) => view.id == fixture.viewId);
    expect(persisted.visibleProperties, ['p:${fixture.propertyId}']);
    expect(persisted.propertyOrder, ['p:${fixture.propertyId}']);
  });

  test(
    'malformed config is privacy-safe and does not block other Views',
    () async {
      final fixture = await _ViewAuditFixture.create();
      addTearDown(fixture.close);

      final malformedViewId = await fixture.viewStore.createView(
        workspaceId: fixture.workspaceId,
        definition: fixture.definition,
        name: 'Malformed private view name',
        layoutType: 'table',
      );
      await fixture.database.customStatement(
        '''UPDATE database_views
         SET filters_json = ?, sorts_json = ?, settings_json = ?
         WHERE id = ?''',
        [
          '{"private":"unterminated"',
          '{"not":"a list"}',
          '["not-a-map"]',
          malformedViewId,
        ],
      );

      final result = await fixture.audit.run(workspaceId: fixture.workspaceId);
      final malformed = result.findings
          .where((finding) => finding.viewId == malformedViewId)
          .map((finding) => finding.kind)
          .toSet();

      expect(
        malformed,
        containsAll(<DatabaseViewHealthIssueKind>{
          DatabaseViewHealthIssueKind.malformedFilters,
          DatabaseViewHealthIssueKind.malformedSorts,
          DatabaseViewHealthIssueKind.malformedSettings,
        }),
      );
      expect(
        result.findings.where((finding) => finding.viewId == fixture.viewId),
        isEmpty,
      );
    },
  );
}

class _ViewAuditFixture {
  _ViewAuditFixture({
    required this.database,
    required this.workspaceId,
    required this.objectTypeId,
    required this.propertyId,
    required this.viewId,
    required this.viewStore,
    required this.definition,
    required this.audit,
  });

  final AppDatabase database;
  final int workspaceId;
  final int objectTypeId;
  final int propertyId;
  final int viewId;
  final DatabaseViewStore viewStore;
  final DatabaseDefinition definition;
  final DatabaseViewHealthAudit audit;

  static Future<_ViewAuditFixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final viewStore = DatabaseViewStore(database);

    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final propertyId = await objectStore.createRelationProperty(
      objectTypeId: objectTypeId,
      name: 'Related',
      targetObjectTypeId: targetTypeId,
      multiple: true,
    );
    final definition = DatabaseDefinition(
      key: 'custom:$objectTypeId',
      label: 'Source',
      icon: Icons.folder_outlined,
      properties: const <DatabasePropertyDefinition>[],
      defaultLayout: 'table',
    );
    final viewId = await viewStore.createView(
      workspaceId: workspaceId,
      definition: definition,
      name: 'Healthy',
      layoutType: 'table',
      visibleProperties: ['p:$propertyId'],
      propertyOrder: ['p:$propertyId'],
    );
    var view = (await viewStore.listWorkspaceViews(workspaceId: workspaceId))
        .singleWhere((candidate) => candidate.id == viewId);
    view = const DatabaseViewQueryAdapter().encode(
      view,
      filters: <ObjectFilterRule>[
        ObjectFilterRule(
          propertyId: propertyId,
          operator: ObjectFilterOperator.isNotEmpty,
        ),
      ],
      sorts: <ObjectSortRule>[
        ObjectSortRule(
          propertyId: propertyId,
          direction: ObjectSortDirection.ascending,
        ),
      ],
    );
    view = const DatabaseViewGroupAdapter().encode(
      view,
      group: ObjectGroupRule(propertyId: propertyId),
    );
    view = const DatabaseViewGalleryAdapter().encodeCoverSource(
      view,
      source: GalleryCoverSource.imageRelation(propertyId),
    );
    await viewStore.updateView(view);

    return _ViewAuditFixture(
      database: database,
      workspaceId: workspaceId,
      objectTypeId: objectTypeId,
      propertyId: propertyId,
      viewId: viewId,
      viewStore: viewStore,
      definition: definition,
      audit: DatabaseViewHealthAudit(
        genericStore: genericStore,
        objectStore: objectStore,
        viewStore: viewStore,
      ),
    );
  }

  Future<void> close() => database.close();
}
