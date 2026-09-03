import 'package:flutter/material.dart';

import '../../../data/database_view_store.dart';
import '../../../data/object_open_presentation_service.dart';
import '../../../domain/object_type_defaults.dart';

/// Presents shared Object detail content according to the resolved opening mode.
///
/// Mode resolution stays in `ObjectOpenPresentationService`; this class owns only
/// the concrete Flutter presentation so Database/View hosts do not duplicate
/// modal/page routing logic.
class ObjectOpenPresentationHost {
  const ObjectOpenPresentationHost();

  /// Resolves the canonical opening mode and immediately presents the Object.
  ///
  /// Real Database/View hosts can call this entry point without reimplementing
  /// the `View > Database > ObjectType > app` precedence before delegating to
  /// [open]. The resolved mode is returned to make host-level regression tests
  /// and telemetry straightforward without coupling them to navigation internals.
  Future<ObjectOpenMode> openResolved({
    required BuildContext context,
    required ObjectOpenPresentationService resolver,
    required DatabaseViewConfig view,
    required int objectTypeId,
    required VoidCallback onSidePeek,
    required WidgetBuilder detailBuilder,
    ObjectOpenMode? databaseOverride,
    ObjectOpenMode appFallback = ObjectOpenMode.sidePeek,
  }) async {
    final mode = await resolver.resolve(
      view: view,
      objectTypeId: objectTypeId,
      databaseOverride: databaseOverride,
      appFallback: appFallback,
    );
    await open(
      context: context,
      mode: mode,
      onSidePeek: onSidePeek,
      detailBuilder: detailBuilder,
    );
    return mode;
  }

  Future<void> open({
    required BuildContext context,
    required ObjectOpenMode mode,
    required VoidCallback onSidePeek,
    required WidgetBuilder detailBuilder,
  }) async {
    switch (mode) {
      case ObjectOpenMode.sidePeek:
        onSidePeek();
        return;
      case ObjectOpenMode.centerPeek:
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 840,
                maxHeight: 760,
              ),
              child: SizedBox(
                width: 760,
                height: 680,
                child: detailBuilder(dialogContext),
              ),
            ),
          ),
        );
        return;
      case ObjectOpenMode.fullPage:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: detailBuilder),
        );
        return;
    }
  }
}
