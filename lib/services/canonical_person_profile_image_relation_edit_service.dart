import '../data/app_database.dart';
import '../data/object_relation_editor_service.dart';
import '../data/person_object_bridge.dart';
import '../data/relation_target_service.dart';
import '../data/system_object_store.dart';
import 'person_profile_image_relation_service.dart';

/// Routes the canonical Person `Profile Image` Relation through the established
/// compatibility boundary while legacy People UI still exists.
///
/// Every unrelated Relation, including native canonical Person Relations, keeps
/// using the ordinary generic Relation editor. A legacy-backed canonical Person
/// uses [PersonProfileImageRelationService] so its canonical Image Relation and
/// temporary `people.profile_photo_id` projection commit atomically.
///
/// This is an [ObjectRelationEditorService] subtype so a composition root can
/// install it without changing generic picker/search/load call sites.
class CanonicalPersonProfileImageRelationEditService
    extends ObjectRelationEditorService {
  CanonicalPersonProfileImageRelationEditService({
    required this.genericEditor,
    required this.personBridge,
    required this.profileImages,
  }) : super(
          targets: genericEditor.targets,
          mutations: genericEditor.mutations,
          identitySearch: genericEditor.identitySearch,
        );

  factory CanonicalPersonProfileImageRelationEditService.forDatabase({
    required AppDatabase database,
    required ObjectRelationEditorService genericEditor,
  }) {
    final objectStore = genericEditor.targets.objectStore;
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    return CanonicalPersonProfileImageRelationEditService(
      genericEditor: genericEditor,
      personBridge: PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
      ),
      profileImages: PersonProfileImageRelationService(database),
    );
  }

  final ObjectRelationEditorService genericEditor;
  final PersonObjectBridge personBridge;
  final PersonProfileImageRelationService profileImages;

  @override
  Future<void> save({
    required RelationSelectionContext context,
    required Iterable<int> selectedObjectIds,
  }) async {
    final selected = selectedObjectIds.toList(growable: false);
    final workspaceId = context.targetObjectType.workspaceId;
    final personSchema = await personBridge.ensurePersonObjectType(workspaceId);

    if (context.property.objectTypeId != personSchema.objectType.id ||
        context.property.name !=
            PersonProfileImageRelationService.profileImagePropertyName) {
      await genericEditor.save(context: context, selectedObjectIds: selected);
      return;
    }

    final mappedLegacyId = await personBridge.legacyPersonIdForObject(
      workspaceId,
      context.sourceObject.id,
    );
    final claimedValue =
        context.sourceObject.values[personSchema.legacyPersonIdProperty.id];
    final claimedLegacyId = _legacyId(claimedValue);
    if (claimedValue != null && claimedLegacyId == null) {
      throw StateError('Canonical Person legacy identity is malformed.');
    }

    if (mappedLegacyId == null) {
      if (claimedLegacyId != null) {
        throw StateError(
          'Canonical Person claims a legacy identity without a valid mapping.',
        );
      }
      await genericEditor.save(context: context, selectedObjectIds: selected);
      return;
    }

    if (claimedLegacyId != mappedLegacyId) {
      throw StateError(
        'Canonical Person mapping does not match its persisted legacy identity.',
      );
    }

    final canonical = await profileImages.load(
      workspaceId: workspaceId,
      personId: mappedLegacyId,
    );
    if (canonical.personObjectId != context.sourceObject.id ||
        canonical.property.id != context.property.id) {
      await genericEditor.save(context: context, selectedObjectIds: selected);
      return;
    }

    if (selected.length > 1) {
      throw ArgumentError.value(
        selected,
        'selectedObjectIds',
        'Canonical Person Profile Image accepts at most one Image.',
      );
    }

    if (selected.isEmpty) {
      await profileImages.clearProfileImage(
        workspaceId: workspaceId,
        personId: mappedLegacyId,
      );
      return;
    }

    await profileImages.setProfileImage(
      workspaceId: workspaceId,
      personId: mappedLegacyId,
      imageObjectId: selected.single,
    );
  }

  int? _legacyId(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse('$value');
  }
}
