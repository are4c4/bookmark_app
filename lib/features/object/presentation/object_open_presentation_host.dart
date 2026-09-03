import 'package:flutter/material.dart';

import '../../../domain/object_type_defaults.dart';

/// Presents shared Object detail content according to the resolved opening mode.
///
/// Mode resolution stays in `ObjectOpenPresentationService`; this class owns only
/// the concrete Flutter presentation so Database/View hosts do not duplicate
/// modal/page routing logic.
class ObjectOpenPresentationHost {
  const ObjectOpenPresentationHost();

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
