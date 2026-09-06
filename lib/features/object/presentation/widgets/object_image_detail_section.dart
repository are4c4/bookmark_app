import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/generic_database_store.dart';
import '../../../../data/image_object_service.dart';
import '../../../../data/object_store.dart';
import '../../../../data/object_type_defaults_store.dart';
import '../../../../data/system_object_store.dart';
import '../../../../services/canonical_image_edit_service.dart';
import '../../../../services/image_managed_file_deletion_policy.dart';
import '../../../../services/photo_storage_service.dart';
import 'object_image_detail_preview.dart';
import 'object_image_edit_actions.dart';

/// Canonical Image detail media surface shared by Object detail hosts.
///
/// This keeps managed-file ownership checks, edit actions and same-path preview
/// refresh behind one feature-local seam. A host only needs to render this for
/// the canonical Image system ObjectType; it never passes a raw editable path.
class ObjectImageDetailSection extends StatefulWidget {
  ObjectImageDetailSection({
    super.key,
    required this.database,
    required this.objectStore,
    required this.editService,
    required this.workspaceId,
    required this.objectTypeId,
    required this.objectId,
    this.onChanged,
    this.onError,
    this.maxPreviewHeight = 480,
    this.previewImageBuilder,
    this.previewCacheEvictor,
  });

  factory ObjectImageDetailSection.fromStores({
    Key? key,
    required GenericDatabaseStore store,
    required ObjectStore objectStore,
    required int workspaceId,
    required int objectTypeId,
    required int objectId,
    PhotoStorageService photoStorage = const PhotoStorageService(),
    VoidCallback? onChanged,
    void Function(Object error)? onError,
    double maxPreviewHeight = 480,
    Widget Function(BuildContext context, String filePath)? previewImageBuilder,
    ObjectImagePreviewCacheEvictor? previewCacheEvictor,
  }) {
    final systemObjects = SystemObjectStore(
      database: store.database,
      objectStore: objectStore,
    );
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(store),
    );
    final ownershipPolicy = ImageManagedFileDeletionPolicy(
      database: store.database,
      objectStore: objectStore,
      photoStorage: photoStorage,
    );
    return ObjectImageDetailSection(
      key: key,
      database: store.database,
      objectStore: objectStore,
      editService: CanonicalImageEditService.fromServices(
        ownershipPolicy: ownershipPolicy,
        images: images,
      ),
      workspaceId: workspaceId,
      objectTypeId: objectTypeId,
      objectId: objectId,
      onChanged: onChanged,
      onError: onError,
      maxPreviewHeight: maxPreviewHeight,
      previewImageBuilder: previewImageBuilder,
      previewCacheEvictor: previewCacheEvictor,
    );
  }

  final AppDatabase database;
  final ObjectStore objectStore;
  final CanonicalImageEditService editService;
  final int workspaceId;
  final int objectTypeId;
  final int objectId;
  final VoidCallback? onChanged;
  final void Function(Object error)? onError;
  final double maxPreviewHeight;
  final Widget Function(BuildContext context, String filePath)?
      previewImageBuilder;
  final ObjectImagePreviewCacheEvictor? previewCacheEvictor;

  @override
  State<ObjectImageDetailSection> createState() =>
      _ObjectImageDetailSectionState();
}

class _ObjectImageDetailSectionState extends State<ObjectImageDetailSection> {
  int _refreshToken = 0;

  @override
  void didUpdateWidget(covariant ObjectImageDetailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.objectId != widget.objectId) {
      _refreshToken = 0;
    }
  }

  void _handleChanged() {
    if (mounted) {
      setState(() => _refreshToken++);
    }
    widget.onChanged?.call();
  }

  void _handleError(Object error) {
    final callback = widget.onError;
    if (callback != null) {
      callback(error);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('画像を編集できませんでした: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('object-image-detail-section-${widget.objectId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObjectImageDetailPreview(
          database: widget.database,
          objectStore: widget.objectStore,
          objectTypeId: widget.objectTypeId,
          objectId: widget.objectId,
          maxHeight: widget.maxPreviewHeight,
          refreshToken: _refreshToken,
          imageBuilder: widget.previewImageBuilder,
          cacheEvictor: widget.previewCacheEvictor,
        ),
        const SizedBox(height: 12),
        ObjectImageEditActions(
          editService: widget.editService,
          workspaceId: widget.workspaceId,
          objectId: widget.objectId,
          onChanged: _handleChanged,
          onError: _handleError,
        ),
      ],
    );
  }
}
