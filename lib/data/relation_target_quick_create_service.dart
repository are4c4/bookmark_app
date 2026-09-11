import 'dart:developer' as developer;

import '../domain/object_model.dart';
import 'canonical_object_mutation_impact_sink.dart';
import 'canonical_weblink_capture_service.dart';
import 'object_store.dart';
import 'person_object_write_service.dart';
import 'relation_target_quick_create_policy.dart';
import 'tag_object_bridge.dart';
import 'weblink_object_service.dart';

typedef RelationManagedTargetCreate = Future<int?> Function();
typedef RelationQuickCreateWeblinkEnricher = Future<void> Function({
  required int workspaceId,
  required int objectId,
  required String url,
});

/// Executes Relation target quick-create without introducing a generic
/// title-only escape hatch for identity-sensitive system primitives.
///
/// The read-only [RelationTargetQuickCreatePolicy] decides the canonical mode.
/// Custom ObjectTypes use normal Object creation, Person and Tag creation use
/// their canonical migration-safe write boundaries, Weblinks use the canonical
/// capture boundary, and Image/File require caller-supplied managed-import
/// callbacks. Every result is reloaded from the configured target ObjectType
/// before being returned.
class RelationTargetQuickCreateService {
  const RelationTargetQuickCreateService({
    required this.policy,
    required this.objectStore,
    required this.tagBridge,
    required this.weblinks,
    this.weblinkEnricher,
    this.canonicalObjectMutationImpactSink,
  });

  final RelationTargetQuickCreatePolicy policy;
  final ObjectStore objectStore;
  final TagObjectBridge tagBridge;
  final WeblinkObjectService weblinks;
  final RelationQuickCreateWeblinkEnricher? weblinkEnricher;
  final CanonicalObjectMutationImpactSink? canonicalObjectMutationImpactSink;

  Future<AppObject?> create({
    required int workspaceId,
    required int targetObjectTypeId,
    String? input,
    RelationManagedTargetCreate? createManagedImage,
    RelationManagedTargetCreate? createManagedFile,
  }) async {
    final mode = await policy.modeFor(
      workspaceId: workspaceId,
      targetObjectTypeId: targetObjectTypeId,
    );

    switch (mode) {
      case RelationTargetQuickCreateMode.genericObject:
        final title = _requiredInput(input, 'Object title');
        final objectId = await objectStore.createObject(
          objectTypeId: targetObjectTypeId,
          title: title,
        );
        return _validatedTarget(
          workspaceId: workspaceId,
          targetObjectTypeId: targetObjectTypeId,
          objectId: objectId,
        );

      case RelationTargetQuickCreateMode.person:
        final name = _requiredInput(input, 'Person name');
        final impact = await PersonObjectWriteService.forDatabase(
          tagBridge.database,
        ).createWithImpact(workspaceId: workspaceId, name: name);
        final object = await _validatedTarget(
          workspaceId: workspaceId,
          targetObjectTypeId: targetObjectTypeId,
          objectId: impact.canonicalObjectId,
        );
        if (impact.canonicalMutationCommitted) {
          await canonicalObjectMutationImpactSink?.objectCommitted(
            impact.canonicalObjectId,
          );
        }
        return object;

      case RelationTargetQuickCreateMode.tag:
        final name = _requiredInput(input, 'Tag name');
        final objectId = await tagBridge.createLegacyTagObject(
          workspaceId: workspaceId,
          name: name,
        );
        return _validatedTarget(
          workspaceId: workspaceId,
          targetObjectTypeId: targetObjectTypeId,
          objectId: objectId,
        );

      case RelationTargetQuickCreateMode.weblinkUrl:
        final url = _requiredInput(input, 'Weblink URL');
        final object = await CanonicalWeblinkCaptureService(weblinks: weblinks)
            .capture(workspaceId: workspaceId, url: url);
        final enrich = weblinkEnricher;
        if (enrich != null) {
          try {
            await enrich(
              workspaceId: workspaceId,
              objectId: object.id,
              url: url,
            );
          } catch (_, stackTrace) {
            _debugWeblinkEnrichmentFailure(stackTrace);
          }
        }
        return _validatedTarget(
          workspaceId: workspaceId,
          targetObjectTypeId: targetObjectTypeId,
          objectId: object.id,
        );

      case RelationTargetQuickCreateMode.managedImage:
        final createManaged = createManagedImage;
        if (createManaged == null) {
          throw StateError(
            'Image Relation quick-create requires canonical managed Image import.',
          );
        }
        final objectId = await createManaged();
        if (objectId == null) return null;
        return _validatedTarget(
          workspaceId: workspaceId,
          targetObjectTypeId: targetObjectTypeId,
          objectId: objectId,
        );

      case RelationTargetQuickCreateMode.managedFile:
        final createManaged = createManagedFile;
        if (createManaged == null) {
          throw StateError(
            'File Relation quick-create requires canonical managed File import.',
          );
        }
        final objectId = await createManaged();
        if (objectId == null) return null;
        return _validatedTarget(
          workspaceId: workspaceId,
          targetObjectTypeId: targetObjectTypeId,
          objectId: objectId,
        );

      case RelationTargetQuickCreateMode.unavailable:
        throw UnsupportedError(
          'This ObjectType does not support safe Relation target quick-create.',
        );
    }
  }

  String _requiredInput(String? input, String label) {
    final normalized = input?.trim() ?? '';
    if (normalized.isEmpty) {
      throw ArgumentError.value(input, 'input', '$label must not be empty.');
    }
    return normalized;
  }

  Future<AppObject> _validatedTarget({
    required int workspaceId,
    required int targetObjectTypeId,
    required int objectId,
  }) async {
    final targetType = await objectStore.getObjectType(targetObjectTypeId);
    if (targetType == null || targetType.workspaceId != workspaceId) {
      throw StateError('Relation target ObjectType changed during quick-create.');
    }
    final objects = await objectStore.listObjects(targetObjectTypeId);
    for (final object in objects) {
      if (object.id == objectId) return object;
    }
    throw StateError(
      'Quick-create returned an Object outside the configured Relation target ObjectType.',
    );
  }

  void _debugWeblinkEnrichmentFailure(StackTrace stackTrace) {
    assert(() {
      developer.log(
        'Optional Relation quick-create Weblink enrichment failed; canonical Weblink is kept.',
        name: 'bookmark_app.relation_quick_create',
        stackTrace: stackTrace,
      );
      return true;
    }());
  }
}
