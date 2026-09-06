import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/object_store.dart';
import '../../../../services/canonical_image_edit_service.dart';
import 'object_image_detail_preview.dart';
import 'object_image_edit_actions.dart';

/// Canonical Image detail presentation seam.
///
/// This keeps the same-path preview refresh contract next to the safe edit
/// actions, so shared Object-detail hosts do not need to coordinate file-cache
/// invalidation themselves. All byte mutations remain behind
/// [CanonicalImageEditService].
class ObjectImageDetailPanel extends StatefulWidget {
  const ObjectImageDetailPanel({
    super.key,
    required this.database,
    required this.objectStore,
    required this.workspaceId,
    required this.objectTypeId,
    required this.objectId,
    required this.editService,
    this.onError,
    this.maxPreviewHeight = 480,
    this.previewImageBuilder,
    this.previewCacheEvictor,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int workspaceId;
  final int objectTypeId;
  final int objectId;
  final CanonicalImageEditService editService;
  final void Function(Object error)? onError;
  final double maxPreviewHeight;
  final Widget Function(BuildContext context, String filePath)? previewImageBuilder;
  final ObjectImagePreviewCacheEvictor? previewCacheEvictor;

  @override
  State<ObjectImageDetailPanel> createState() => _ObjectImageDetailPanelState();
}

class _ObjectImageDetailPanelState extends State<ObjectImageDetailPanel> {
  int _previewRefreshToken = 0;

  @override
  void didUpdateWidget(covariant ObjectImageDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.objectId != widget.objectId) {
      _previewRefreshToken = 0;
    }
  }

  void _handleChanged() {
    setState(() => _previewRefreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('object-image-detail-panel-${widget.objectId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObjectImageDetailPreview(
          database: widget.database,
          objectStore: widget.objectStore,
          objectTypeId: widget.objectTypeId,
          objectId: widget.objectId,
          maxHeight: widget.maxPreviewHeight,
          refreshToken: _previewRefreshToken,
          imageBuilder: widget.previewImageBuilder,
          cacheEvictor: widget.previewCacheEvictor,
        ),
        const SizedBox(height: 12),
        ObjectImageEditActions(
          editService: widget.editService,
          workspaceId: widget.workspaceId,
          objectId: widget.objectId,
          onChanged: _handleChanged,
          onError: widget.onError,
        ),
      ],
    );
  }
}
