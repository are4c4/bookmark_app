import '../domain/object_body_plain_text.dart';
import '../domain/object_detail_content.dart';
import '../domain/object_model.dart';
import 'object_body_store.dart';
import 'object_detail_content_loader.dart';
import 'object_store.dart';

/// Narrow Object-owned mutation facade for shared detail surfaces.
///
/// Relation mutation is intentionally excluded. Side/center/full-page editors
/// can use this service for title, ordinary Value Properties and paragraph Body
/// changes, while Relation edits are delegated to the Relation lane facade.
class ObjectDetailEditService {
  ObjectDetailEditService({
    required this.objectStore,
    required this.bodyStore,
    required this.loader,
    this.bodyAdapter = const ObjectBodyPlainTextAdapter(),
  });

  final ObjectStore objectStore;
  final ObjectBodyStore bodyStore;
  final ObjectDetailContentLoader loader;
  final ObjectBodyPlainTextAdapter bodyAdapter;

  Future<ObjectDetailContent> rename({
    required ObjectDetailContent content,
    required String title,
  }) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Object title cannot be empty.');
    }
    await objectStore.renameObject(content.object.id, normalized);
    return _reload(content);
  }

  Future<ObjectDetailContent> setValue({
    required ObjectDetailContent content,
    required ObjectPropertyDefinition property,
    required dynamic value,
  }) async {
    final canonical = _propertyFor(content.objectType, property.id);
    if (canonical == null) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Property does not belong to this ObjectType.',
      );
    }
    if (!canonical.isValue) {
      throw ArgumentError.value(
        canonical.type,
        'property',
        'Object detail Value editing does not mutate Relation or Computed properties.',
      );
    }
    await objectStore.setPropertyValue(
      objectId: content.object.id,
      property: canonical,
      value: value,
    );
    return _reload(content);
  }

  Future<ObjectDetailContent> setPlainTextBody({
    required ObjectDetailContent content,
    required String text,
    required String Function(int index) blockIdForIndex,
  }) async {
    final updated = bodyAdapter.write(
      document: content.body,
      text: text,
      blockIdForIndex: blockIdForIndex,
    );
    if (updated.isEmpty) {
      await bodyStore.clear(content.object.id);
    } else {
      await bodyStore.write(objectId: content.object.id, document: updated);
    }
    return _reload(content);
  }

  ObjectPropertyDefinition? _propertyFor(AppObjectType type, int propertyId) {
    for (final property in type.properties) {
      if (property.id == propertyId) return property;
    }
    return null;
  }

  Future<ObjectDetailContent> _reload(ObjectDetailContent content) async {
    final reloaded = await loader.load(
      objectTypeId: content.objectType.id,
      objectId: content.object.id,
    );
    if (reloaded == null) {
      throw StateError('Object disappeared while editing its detail content.');
    }
    return reloaded;
  }
}
