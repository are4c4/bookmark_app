import '../data/app_database.dart';
import '../data/bidirectional_relation_store.dart';
import '../data/generic_database_store.dart';
import '../data/image_object_service.dart';
import '../data/object_store.dart';
import '../data/object_type_defaults_store.dart';
import '../data/relation_mutation_service.dart';
import '../data/system_object_store.dart';
import '../data/weblink_image_schema_service.dart';
import '../data/weblink_object_service.dart';
import '../domain/object_model.dart';
import 'remote_image_storage_service.dart';

/// Converts a Weblink's remote preview metadata into a canonical managed Image.
///
/// Optional enrichment failures never change Weblink identity. When an image is
/// available, the final Weblink -> Representative image write always goes
/// through the canonical Relation mutation boundary.
class WeblinkPreviewImagePipeline {
  WeblinkPreviewImagePipeline({
    required AppDatabase database,
    required this.objectStore,
    required this.systemObjectStore,
    RemoteImageStorageService? remoteStorage,
  })  : _genericStore = GenericDatabaseStore(database),
        _remoteStorage = remoteStorage ?? RemoteImageStorageService();

  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  final GenericDatabaseStore _genericStore;
  final RemoteImageStorageService _remoteStorage;

  late final ObjectTypeDefaultsStore _defaultsStore =
      ObjectTypeDefaultsStore(_genericStore);
  late final WeblinkObjectService _weblinks = WeblinkObjectService(
        systemObjects: systemObjectStore,
        defaultsStore: _defaultsStore,
      );
  late final ImageObjectService _images = ImageObjectService(
        systemObjects: systemObjectStore,
        defaultsStore: _defaultsStore,
      );
  late final WeblinkImageSchemaService _schema = WeblinkImageSchemaService(
        systemObjects: systemObjectStore,
        defaultsStore: _defaultsStore,
      );
  late final RelationMutationService _relations = RelationMutationService(
        objectStore: objectStore,
        genericStore: _genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: _genericStore,
          objectStore: objectStore,
        ),
      );

  /// Returns the canonical representative Image id, or null when the Weblink has
  /// no usable preview metadata / the optional remote download fails.
  Future<int?> ingestIfMissing({
    required int workspaceId,
    required int weblinkObjectId,
  }) async {
    if (workspaceId <= 0) {
      throw ArgumentError.value(workspaceId, 'workspaceId');
    }

    final schema = await _schema.ensureDefinition(workspaceId);
    final weblinkDefinition = await _weblinks.ensureDefinition(workspaceId);
    final imageDefinition = await _images.ensureDefinition(workspaceId);
    if (schema.weblinkObjectTypeId != weblinkDefinition.objectType.id ||
        schema.imageObjectTypeId != imageDefinition.objectType.id) {
      throw StateError('Weblink/Image system schema identity mismatch.');
    }

    var weblink = await _objectById(
      objectTypeId: schema.weblinkObjectTypeId,
      objectId: weblinkObjectId,
      label: 'Weblink',
    );
    final currentRepresentative = ObjectRelationValue.fromJson(
      weblink.values[schema.representativeImageProperty.id],
    ).objectIds;
    if (currentRepresentative.length > 1) {
      throw StateError('Representative image Relation contains multiple ids.');
    }
    if (currentRepresentative.isNotEmpty) {
      final imageId = currentRepresentative.single;
      await _objectById(
        objectTypeId: schema.imageObjectTypeId,
        objectId: imageId,
        label: 'Representative Image',
      );
      return imageId;
    }

    final rawPreview =
        '${weblink.values[weblinkDefinition.previewImageUrlProperty.id] ?? ''}'
            .trim();
    if (rawPreview.isEmpty) return null;

    String previewUrl;
    try {
      previewUrl = _weblinks.normalizeUrl(rawPreview);
    } on ArgumentError {
      return null;
    }

    final existingImage = await _findImageBySourceUrl(
      imageDefinition: imageDefinition,
      sourceUrl: previewUrl,
    );
    if (existingImage != null) {
      await _attachRepresentative(
        weblinkObjectId: weblinkObjectId,
        imageObjectId: existingImage.id,
        schema: schema,
      );
      return existingImage.id;
    }

    ManagedRemoteImage? managed;
    try {
      managed = await _remoteStorage.download(previewUrl);
    } on ArgumentError {
      // Preview metadata is optional. Unsupported/non-HTTP remote metadata must
      // never make the canonical Weblink or Bookmark path fail.
      return null;
    }
    if (managed == null) return null;

    final image = await _images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      sourceUrl: managed.sourceUrl,
      originalFilename: managed.originalName,
      contentType: managed.contentType,
      pixelWidth: managed.pixelWidth,
      pixelHeight: managed.pixelHeight,
    );
    await _attachRepresentative(
      weblinkObjectId: weblinkObjectId,
      imageObjectId: image.id,
      schema: schema,
    );

    // Reload once so callers never observe success before the canonical Relation
    // Value/index pair is durable.
    weblink = await _objectById(
      objectTypeId: schema.weblinkObjectTypeId,
      objectId: weblinkObjectId,
      label: 'Weblink',
    );
    final persisted = ObjectRelationValue.fromJson(
      weblink.values[schema.representativeImageProperty.id],
    ).objectIds;
    if (persisted.length != 1 || persisted.single != image.id) {
      throw StateError('Representative image Relation verification failed.');
    }
    return image.id;
  }

  Future<AppObject?> _findImageBySourceUrl({
    required ImageObjectDefinition imageDefinition,
    required String sourceUrl,
  }) async {
    for (final image
        in await objectStore.listObjects(imageDefinition.objectType.id)) {
      final stored =
          '${image.values[imageDefinition.sourceUrlProperty.id] ?? ''}'.trim();
      if (stored == sourceUrl) return image;
    }
    return null;
  }

  Future<void> _attachRepresentative({
    required int weblinkObjectId,
    required int imageObjectId,
    required WeblinkImageSchemaDefinition schema,
  }) async {
    await _relations.setRelation(
      objectId: weblinkObjectId,
      property: schema.representativeImageProperty,
      targetObjectIds: <int>[imageObjectId],
    );

    final weblink = await _objectById(
      objectTypeId: schema.weblinkObjectTypeId,
      objectId: weblinkObjectId,
      label: 'Weblink',
    );
    final persisted = ObjectRelationValue.fromJson(
      weblink.values[schema.representativeImageProperty.id],
    ).objectIds;
    if (persisted.length != 1 || persisted.single != imageObjectId) {
      throw StateError('Representative image Relation value did not persist.');
    }
    final edges = (await objectStore.outgoingRelations(weblinkObjectId))
        .where(
          (edge) => edge.propertyId == schema.representativeImageProperty.id,
        )
        .toList(growable: false);
    if (edges.length != 1 || edges.single.targetObjectId != imageObjectId) {
      throw StateError('Representative image Relation index did not persist.');
    }
  }

  Future<AppObject> _objectById({
    required int objectTypeId,
    required int objectId,
    required String label,
  }) async {
    for (final object in await objectStore.listObjects(objectTypeId)) {
      if (object.id == objectId) return object;
    }
    throw ArgumentError.value(
      objectId,
      'objectId',
      '$label Object does not exist in the expected system ObjectType.',
    );
  }
}
