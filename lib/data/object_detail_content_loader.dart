import '../domain/object_detail_content.dart';
import '../domain/object_model.dart';
import 'object_body_store.dart';
import 'object_computed_value_store.dart';
import 'object_store.dart';

/// Builds the shared Object detail payload used by side peek, center peek and
/// full-page presentations.
///
/// Presentation/navigation remains outside this loader. Relation/backlink UI
/// may compose additional Relation-lane data around the same Object content.
class ObjectDetailContentLoader {
  ObjectDetailContentLoader({
    required this.objectStore,
    required this.bodyStore,
    required this.computedStore,
  });

  final ObjectStore objectStore;
  final ObjectBodyStore bodyStore;
  final ObjectComputedValueStore computedStore;

  Future<ObjectDetailContent?> load({
    required int objectTypeId,
    required int objectId,
  }) async {
    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null) return null;

    AppObject? object;
    for (final candidate in await objectStore.listObjects(objectTypeId)) {
      if (candidate.id == objectId) {
        object = candidate;
        break;
      }
    }
    if (object == null) return null;

    final body = await bodyStore.read(object.id);
    final computedValues = <int, dynamic>{};
    for (final property in objectType.properties) {
      if (!property.isComputed) continue;
      computedValues[property.id] = await computedStore.evaluate(
        object: object,
        property: property,
      );
    }

    return ObjectDetailContent(
      object: object,
      objectType: objectType,
      body: body,
      computedValues: Map<int, dynamic>.unmodifiable(computedValues),
    );
  }
}
