import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'object_type_defaults_store.dart';

/// Canonical Lane A deletion boundary for ordinary Object Properties.
///
/// Property ids stored inside [ObjectTypeDefaults] are JSON references rather
/// than foreign keys. Deleting a Property through this service therefore prunes
/// ObjectType-owned visibility/order defaults before removing the Property row,
/// and performs both mutations in one transaction.
///
/// Relation Properties deliberately remain outside this boundary because their
/// lifecycle and paired/index integrity belong to the canonical Relation APIs.
class ObjectPropertyDeletionService {
  ObjectPropertyDeletionService({
    required GenericDatabaseStore genericStore,
    required ObjectStore objectStore,
    ObjectTypeDefaultsStore? defaultsStore,
  })  : _genericStore = genericStore,
        _objectStore = objectStore,
        _defaultsStore = defaultsStore ?? ObjectTypeDefaultsStore(genericStore);

  final GenericDatabaseStore _genericStore;
  final ObjectStore _objectStore;
  final ObjectTypeDefaultsStore _defaultsStore;

  Future<void> deleteProperty(ObjectPropertyDefinition property) async {
    final type = await _objectStore.getObjectType(property.objectTypeId);
    if (type == null) {
      throw ArgumentError.value(
        property.objectTypeId,
        'property',
        'ObjectType does not exist.',
      );
    }

    ObjectPropertyDefinition? stored;
    for (final candidate in type.properties) {
      if (candidate.id == property.id) {
        stored = candidate;
        break;
      }
    }
    final storedProperty = stored;
    if (storedProperty == null) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Property does not belong to ObjectType ${property.objectTypeId}.',
      );
    }
    if (storedProperty.isRelation) {
      throw StateError(
        'Relation Properties must be deleted through canonical Relation lifecycle APIs.',
      );
    }

    await _defaultsStore.ensureSchema();
    await _genericStore.database.transaction(() async {
      final current = await _defaultsStore.read(storedProperty.objectTypeId);
      if (current != null) {
        final visiblePropertyIds = _withoutProperty(
          current.visiblePropertyIds,
          storedProperty.id,
        );
        final propertyOrder = _withoutProperty(
          current.propertyOrder,
          storedProperty.id,
        );
        final changed =
            visiblePropertyIds?.length != current.visiblePropertyIds?.length ||
                propertyOrder?.length != current.propertyOrder?.length;
        if (changed) {
          await _defaultsStore.write(
            objectTypeId: storedProperty.objectTypeId,
            defaults: ObjectTypeDefaults(
              visiblePropertyIds: visiblePropertyIds,
              propertyOrder: propertyOrder,
              openMode: current.openMode,
              bodyTemplate: current.bodyTemplate,
            ),
          );
        }
      }

      await _objectStore.deleteProperty(storedProperty.id);
    });
  }

  List<int>? _withoutProperty(List<int>? ids, int propertyId) {
    if (ids == null) return null;
    return ids.where((id) => id != propertyId).toList(growable: false);
  }
}
