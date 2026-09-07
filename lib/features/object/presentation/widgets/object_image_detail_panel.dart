import 'package:flutter/material.dart';

import '../../../../data/object_store.dart';
import '../../../../data/profile_path_resolver.dart';
import '../../../../services/canonical_image_edit_service.dart';
import 'object_image_detail_preview.dart';
import 'object_image_edit_actions.dart';
import 'object_image_free_crop_dialog.dart';

/// Canonical Image detail presentation seam.
///
/// This keeps the same-path preview refresh contract next to the safe edit
/// actions, so shared Object-detail hosts do not need to coordinate file-cache
/// invalidation themselves. All byte mutations remain behind
/// [CanonicalImageEditService].
class ObjectImageDetailPanel extends StatefulWidget {
  const ObjectImageDetailPanel({
    super.key,
    required this.pathResolver,
    required this.objectStore,
    required this.workspaceId,
    required this.objectTypeId,
    required this.objectId,
    required this.editService,
    this.onChanged,
    this.onError,
    this.maxPreviewHeight = 480,
    this.previewImageBuilder,
    this.previewCacheEvictor,
    this.previewVisualResolver,
  });

  final ProfilePathResolver pathResolver;
  final ObjectStore objectStore;
  final int workspaceId;
  final int objectTypeId;
  final int objectId;
  final CanonicalImageEditService editService;

  /// Notifies the host after bytes and canonical geometry were updated.
  ///
  /// The panel schedules its own same-path preview refresh before invoking this
  /// callback; hosts may use it to re-read surrounding metadata rows such as
  /// Pixel width/height without learning about file-cache invalidation details.
  final VoidCallback? onChanged;
  final void Function(Object error)? onError;
  final double maxPreviewHeight;
  final Widget Function(BuildContext context, String filePath)? previewImageBuilder;
  final ObjectImagePreviewCacheEvictor? previewCacheEvictor;

  /// Optional preview read seam forwarded to [ObjectImageDetailPreview].
  /// Production hosts leave this null; focused widget tests can keep resolver,
  /// filesystem and codec coverage in their existing dedicated tests.
  final ObjectImagePreviewVisualResolver? previewVisualResolver;

  @override
  State<ObjectImageDetailPanel> createState() => _ObjectImageDetailPanelState();
}

class _ObjectImageDetailPanelState extends State<ObjectImageDetailPanel> {
  int _previewRefreshToken = 0;

  @override
  void didUpdateWidget(covariant ObjectImageDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pathResolver != widget.pathResolver ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.objectId != widget.objectId) {
      _previewRefreshToken = 0;
    }
  }

  void _handleChanged() {
    if (!mounted) return;
    setState(() => _previewRefreshToken++);
    widget.onChanged?.call();
  }

  Future<Rect?> _selectFreeCrop(BuildContext context) => showDialog<Rect>(
        context: context,
        builder: (_) => ObjectImageFreeCropDialog(
          pathResolver: widget.pathResolver,
          objectStore: widget.objectStore,
          objectTypeId: widget.objectTypeId,
          objectId: widget.objectId,
          visualResolver: widget.previewVisualResolver,
          imageBuilder: widget.previewImageBuilder,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('object-image-detail-panel-${widget.objectId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObjectImageDetailPreview(
          pathResolver: widget.pathResolver,
          objectStore: widget.objectStore,
          objectTypeId: widget.objectTypeId,
          objectId: widget.objectId,
          maxHeight: widget.maxPreviewHeight,
          refreshToken: _previewRefreshToken,
          imageBuilder: widget.previewImageBuilder,
          cacheEvictor: widget.previewCacheEvictor,
          visualResolver: widget.previewVisualResolver,
        ),
        const SizedBox(height: 12),
        ObjectImageEditActions(
          editService: widget.editService,
          workspaceId: widget.workspaceId,
          objectId: widget.objectId,
          freeCropSelector: _selectFreeCrop,
          onChanged: _handleChanged,
          onError: widget.onError,
        ),
      ],
    );
  }
}
