import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../data/app_database.dart';
import '../../../../data/image_object_service.dart';
import '../../../../data/object_store.dart';
import '../../../../data/system_object_store.dart';
import '../../../../data/weblink_object_service.dart';
import '../../../../services/image_visual_resolver.dart';
import '../../../../services/weblink_visual_resolver.dart';

enum SystemObjectListMediaKind {
  fallback,
  weblink,
  image,
}

class SystemObjectListMediaResolution {
  const SystemObjectListMediaResolution({
    required this.kind,
    this.filePath,
  });

  final SystemObjectListMediaKind kind;
  final String? filePath;
}

typedef SystemObjectListMediaResolver = Future<SystemObjectListMediaResolution>
    Function({
  required int workspaceId,
  required int objectTypeId,
  required int objectId,
});

typedef SystemObjectListMediaImageBuilder = Widget Function(
  BuildContext context,
  String filePath,
  Widget Function() errorFallback,
);

/// Read-only leading media for generic Object List rows.
///
/// Canonical Weblinks reuse their managed Representative Image and canonical
/// Images reuse their managed File. Unsupported/custom ObjectTypes retain the
/// generic document icon. Resolution is presentation-only and never ensures
/// schema or mutates Object/Relation state.
class SystemObjectListMedia extends StatefulWidget {
  const SystemObjectListMedia({
    super.key,
    required this.database,
    required this.objectStore,
    required this.workspaceId,
    required this.objectTypeId,
    required this.objectId,
    this.size = 44,
    this.visualResolver,
    this.imageBuilder,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int workspaceId;
  final int objectTypeId;
  final int objectId;
  final double size;

  /// Optional presentation seam for focused widget tests/hosts. Production
  /// callers leave this null and use the canonical system Object + visual
  /// resolvers below.
  final SystemObjectListMediaResolver? visualResolver;
  final SystemObjectListMediaImageBuilder? imageBuilder;

  @override
  State<SystemObjectListMedia> createState() => _SystemObjectListMediaState();
}

class _SystemObjectListMediaState extends State<SystemObjectListMedia> {
  late Future<SystemObjectListMediaResolution> _resolution;

  @override
  void initState() {
    super.initState();
    _resolution = _resolve();
  }

  @override
  void didUpdateWidget(covariant SystemObjectListMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.objectTypeId != widget.objectTypeId ||
        oldWidget.objectId != widget.objectId ||
        oldWidget.visualResolver != widget.visualResolver) {
      _resolution = _resolve();
    }
  }

  Future<SystemObjectListMediaResolution> _resolve() async {
    if (widget.workspaceId <= 0 ||
        widget.objectTypeId <= 0 ||
        widget.objectId <= 0) {
      return const SystemObjectListMediaResolution(
        kind: SystemObjectListMediaKind.fallback,
      );
    }

    final custom = widget.visualResolver;
    if (custom != null) {
      return custom(
        workspaceId: widget.workspaceId,
        objectTypeId: widget.objectTypeId,
        objectId: widget.objectId,
      );
    }

    final systemObjects = SystemObjectStore(
      database: widget.database,
      objectStore: widget.objectStore,
    );
    final imageType = await systemObjects.getSystemObjectType(
      workspaceId: widget.workspaceId,
      systemKey: ImageObjectService.systemKey,
    );
    if (imageType?.id == widget.objectTypeId) {
      final visual = await ImageVisualResolver(
        widget.objectStore,
        pathResolver: widget.database.pathResolver,
        // List leading media needs only the managed path. Avoid decoding a
        // full image solely to recover missing layout geometry for a 44px slot.
        probeMissingGeometry: false,
      ).resolveManaged(
        imageObjectTypeId: widget.objectTypeId,
        imageObjectId: widget.objectId,
      );
      return SystemObjectListMediaResolution(
        kind: SystemObjectListMediaKind.image,
        filePath: visual?.filePath,
      );
    }

    final weblinkType = await systemObjects.getSystemObjectType(
      workspaceId: widget.workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    );
    if (weblinkType?.id == widget.objectTypeId) {
      final visual = await WeblinkVisualResolver(
        widget.objectStore,
        pathResolver: widget.database.pathResolver,
      ).resolveManagedRepresentative(
        weblinkObjectTypeId: widget.objectTypeId,
        weblinkObjectId: widget.objectId,
      );
      return SystemObjectListMediaResolution(
        kind: SystemObjectListMediaKind.weblink,
        filePath: visual?.filePath,
      );
    }

    return const SystemObjectListMediaResolution(
      kind: SystemObjectListMediaKind.fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SystemObjectListMediaResolution>(
      future: _resolution,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        return SystemObjectListMediaContent(
          objectId: widget.objectId,
          kind: resolved?.kind ?? SystemObjectListMediaKind.fallback,
          filePath: resolved?.filePath,
          size: widget.size,
          imageBuilder: widget.imageBuilder,
        );
      },
    );
  }
}

/// Pure presentation for [SystemObjectListMedia].
class SystemObjectListMediaContent extends StatelessWidget {
  const SystemObjectListMediaContent({
    super.key,
    required this.objectId,
    required this.kind,
    this.filePath,
    this.size = 44,
    this.imageBuilder,
  });

  final int objectId;
  final SystemObjectListMediaKind kind;
  final String? filePath;
  final double size;
  final SystemObjectListMediaImageBuilder? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final safeSize = size.isFinite && size > 0 ? size : 44.0;
    final path = filePath?.trim();
    final hasVisual = path != null && path.isNotEmpty;
    final fallback = () => _fallback(context, safeSize);

    final child = hasVisual
        ? imageBuilder?.call(context, path, fallback) ??
            Image.file(
              File(path),
              width: safeSize,
              height: safeSize,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            )
        : fallback();

    return SizedBox.square(
      key: ValueKey('system-object-list-media-${kind.name}-$objectId'),
      dimension: safeSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }

  Widget _fallback(BuildContext context, double safeSize) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (kind) {
      SystemObjectListMediaKind.image => Icons.image_outlined,
      SystemObjectListMediaKind.weblink => Icons.link,
      SystemObjectListMediaKind.fallback => Icons.description_outlined,
    };
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(alpha: .55),
      child: Center(
        child: Icon(
          icon,
          size: safeSize * .48,
          color: scheme.onSurfaceVariant.withValues(alpha: .72),
        ),
      ),
    );
  }
}
