import '../domain/object_model.dart';
import 'bidirectional_relation_store.dart';
import 'database_view_gallery_adapter.dart';
import 'database_view_group_adapter.dart';
import 'database_view_query_adapter.dart';
import 'database_view_store.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';

enum DatabaseViewPropertyReferenceKind {
  visible,
  order,
  filter,
  sort,
  group,
  galleryCover,
}

class DatabaseViewPropertyReference {
  const DatabaseViewPropertyReference({
    required this.viewId,
    required this.viewName,
    required this.kinds,
  });

  final int viewId;
  final String viewName;
  final Set<DatabaseViewPropertyReferenceKind> kinds;
}

class ObjectPropertyDeleteImpact {
  const ObjectPropertyDeleteImpact({
    required this.property,
    required this.objectsWithStoredValue,
    required this.viewReferences,
    this.pairedRelationProperty,
  });

  final ObjectPropertyDefinition property;
  final int objectsWithStoredValue;
  final List<DatabaseViewPropertyReference> viewReferences;
  final ObjectPropertyDefinition? pairedRelationProperty;

  bool get hasStoredValues => objectsWithStoredValue > 0;
  bool get isReferencedByViews => viewReferences.isNotEmpty;
  bool get hasPairedRelationImpact => pairedRelationProperty != null;
}

/// Schema-UX helpers that preserve stable Property identity and expose impact
/// before a destructive action.
///
/// Rename changes only the persisted Property name. View references continue to
/// use the stable Property id (`p:<id>` or numeric propertyId), so filters,
/// sorts, groups, Gallery cover settings, and Object values remain attached.
/// Relation renames delegate to the canonical Relation mutation facade so
/// bidirectional metadata is validated before schema changes are written.
/// Delete is intentionally inspection-only here: callers must surface this
/// impact before choosing a canonical deletion/archive path. Managed
/// bidirectional Relations also surface their inverse Property because the
/// canonical Relation delete lifecycle removes both schema Properties.
class DatabaseViewPropertySchemaService {
  const DatabaseViewPropertySchemaService({
    required this.objectStore,
    required this.genericStore,
    required this.viewStore,
  });

  final ObjectStore objectStore;
  final GenericDatabaseStore genericStore;
  final DatabaseViewStore viewStore;

  static const _queryAdapter = DatabaseViewQueryAdapter();
  static const _groupAdapter = DatabaseViewGroupAdapter();
  static const _galleryAdapter = DatabaseViewGalleryAdapter();

  BidirectionalRelationStore get _bidirectionalStore => BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      );

  RelationMutationService get _relationMutations => RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: _bidirectionalStore,
        genericStore: genericStore,
      );

  Future<ObjectPropertyDefinition> renameProperty({
    required int objectTypeId,
    required int propertyId,
    required String name,
  }) async {
    final nextName = name.trim();
    if (nextName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Property name must not be empty.');
    }
    final property = await _canonicalCustomProperty(
      objectTypeId: objectTypeId,
      propertyId: propertyId,
    );
    if (property.name == nextName) return property;

    if (property.isRelation) {
      return _relationMutations.renameRelationProperty(
        property: property,
        name: nextName,
      );
    }

    await genericStore.updateProperty(
      GenericPropertyRecord(
        id: property.id,
        databaseId: property.objectTypeId,
        name: nextName,
        type: property.storageType,
        config: property.config,
        sortOrder: property.sortOrder,
      ),
    );
    return _canonicalCustomProperty(
      objectTypeId: objectTypeId,
      propertyId: propertyId,
    );
  }

  Future<ObjectPropertyDeleteImpact> inspectDelete({
    required int objectTypeId,
    required int propertyId,
  }) async {
    final property = await _canonicalCustomProperty(
      objectTypeId: objectTypeId,
      propertyId: propertyId,
    );
    final type = (await objectStore.getObjectType(objectTypeId))!;
    final objects = await objectStore.listObjects(objectTypeId);
    final objectsWithStoredValue = objects
        .where((object) => object.values.containsKey(property.id))
        .length;

    ObjectPropertyDefinition? pairedRelationProperty;
    if (property.isRelation) {
      final hasPairMetadata = property.config['bidirectional'] == true ||
          property.config['inversePropertyId'] != null ||
          property.config['pairRole'] != null;
      if (hasPairMetadata) {
        final pair = await _bidirectionalStore.pairFor(property);
        if (pair == null) {
          throw StateError(
            'Relation Property ${property.name} has inconsistent bidirectional metadata.',
          );
        }
        pairedRelationProperty = pair.inverseProperty;
      }
    }

    final views = await viewStore.listViews(
      workspaceId: type.workspaceId,
      databaseKey: 'custom:$objectTypeId',
    );
    final references = <DatabaseViewPropertyReference>[];
    final propertyKey = 'p:${property.id}';
    for (final view in views) {
      final kinds = <DatabaseViewPropertyReferenceKind>{};
      if (view.visibleProperties.contains(propertyKey)) {
        kinds.add(DatabaseViewPropertyReferenceKind.visible);
      }
      if (view.propertyOrder.contains(propertyKey)) {
        kinds.add(DatabaseViewPropertyReferenceKind.order);
      }
      final query = _queryAdapter.decode(view);
      if (query.filters.any((rule) => rule.propertyId == property.id)) {
        kinds.add(DatabaseViewPropertyReferenceKind.filter);
      }
      if (query.sorts.any((rule) => rule.propertyId == property.id)) {
        kinds.add(DatabaseViewPropertyReferenceKind.sort);
      }
      if (_groupAdapter.decode(view)?.propertyId == property.id) {
        kinds.add(DatabaseViewPropertyReferenceKind.group);
      }
      final cover = _galleryAdapter.decodeCoverSource(view);
      if (cover.isRelation && cover.relationPropertyId == property.id) {
        kinds.add(DatabaseViewPropertyReferenceKind.galleryCover);
      }
      if (kinds.isNotEmpty) {
        references.add(
          DatabaseViewPropertyReference(
            viewId: view.id,
            viewName: view.name,
            kinds: Set<DatabaseViewPropertyReferenceKind>.unmodifiable(kinds),
          ),
        );
      }
    }

    return ObjectPropertyDeleteImpact(
      property: property,
      objectsWithStoredValue: objectsWithStoredValue,
      viewReferences: List<DatabaseViewPropertyReference>.unmodifiable(
        references,
      ),
      pairedRelationProperty: pairedRelationProperty,
    );
  }

  Future<ObjectPropertyDefinition> _canonicalCustomProperty({
    required int objectTypeId,
    required int propertyId,
  }) async {
    final type = await objectStore.getObjectType(objectTypeId);
    if (type == null) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'ObjectType does not exist.',
      );
    }
    if (type.kind == ObjectTypeKind.system) {
      throw StateError('System ObjectType Properties cannot be edited by users.');
    }
    for (final property in type.properties) {
      if (property.id == propertyId) return property;
    }
    throw ArgumentError.value(
      propertyId,
      'propertyId',
      'Property does not belong to the ObjectType.',
    );
  }
}
