import 'package:flutter/material.dart';

import '../data/database_view_gallery_adapter.dart';
import '../data/database_view_gallery_cover_source_service.dart';
import '../data/database_view_store.dart';

/// Shared Gallery cover selector backed by the canonical per-View settings map.
///
/// Hosts provide schema-derived [options]. The menu only persists the selected
/// generic source identity; media resolution remains outside presentation.
class ObjectGalleryCoverSourceMenu extends StatelessWidget {
  const ObjectGalleryCoverSourceMenu({
    super.key,
    required this.view,
    required this.options,
    required this.onViewChanged,
  });

  final DatabaseViewConfig view;
  final List<GalleryCoverSourceOption> options;
  final ValueChanged<DatabaseViewConfig> onViewChanged;

  static const _galleryAdapter = DatabaseViewGalleryAdapter();
  static const _noneOption = GalleryCoverSourceOption(
    source: GalleryCoverSource.none(),
    label: 'なし',
  );

  @override
  Widget build(BuildContext context) {
    final available = options.isEmpty ? const [_noneOption] : options;
    final persisted = _galleryAdapter.decodeCoverSource(view);
    final selected = available
        .where((option) => option.source == persisted)
        .firstOrNull ??
        available
            .where((option) => option.source == const GalleryCoverSource.none())
            .firstOrNull ??
        available.first;

    return PopupMenuButton<GalleryCoverSource>(
      key: const ValueKey('gallery-cover-source-menu'),
      tooltip: 'ギャラリーのカバー',
      initialValue: selected.source,
      onSelected: (source) {
        onViewChanged(
          _galleryAdapter.encodeCoverSource(view, source: source),
        );
      },
      itemBuilder: (_) => available
          .map(
            (option) => PopupMenuItem<GalleryCoverSource>(
              value: option.source,
              child: Row(
                children: [
                  Icon(_icon(option.source.kind), size: 17),
                  const SizedBox(width: 9),
                  Expanded(child: Text(option.label)),
                  if (option.source == selected.source)
                    const Icon(Icons.check, size: 16),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Material(
        color: selected.source.kind == GalleryCoverSourceKind.none
            ? Colors.transparent
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon(selected.source.kind), size: 16),
              const SizedBox(width: 6),
              Text(
                'カバー: ${selected.label}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(GalleryCoverSourceKind kind) => switch (kind) {
        GalleryCoverSourceKind.none => Icons.hide_image_outlined,
        GalleryCoverSourceKind.directImage => Icons.image_outlined,
        GalleryCoverSourceKind.imageRelation => Icons.photo_library_outlined,
        GalleryCoverSourceKind.weblinkRelationRepresentativeImage =>
          Icons.link_outlined,
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
