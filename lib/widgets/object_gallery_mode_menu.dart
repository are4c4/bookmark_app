import 'package:flutter/material.dart';

import '../data/database_view_gallery_adapter.dart';
import '../data/database_view_store.dart';

/// Shared fixed/masonry Gallery geometry control backed by the canonical View
/// `galleryMode` setting.
///
/// Hosts provide the current [view] and persist [onViewChanged]. The control
/// never owns a Bookmark-specific setting, so generic Databases and legacy
/// Bookmark presentation can converge on the same View contract.
class ObjectGalleryModeMenu extends StatelessWidget {
  const ObjectGalleryModeMenu({
    super.key,
    required this.view,
    required this.onViewChanged,
  });

  final DatabaseViewConfig view;
  final ValueChanged<DatabaseViewConfig> onViewChanged;

  static const _galleryAdapter = DatabaseViewGalleryAdapter();

  @override
  Widget build(BuildContext context) {
    final mode = _galleryAdapter.decode(view);
    return PopupMenuButton<GalleryViewMode>(
      key: const ValueKey('gallery-mode-menu'),
      tooltip: 'ギャラリー表示',
      initialValue: mode,
      onSelected: (next) {
        onViewChanged(_galleryAdapter.encode(view, mode: next));
      },
      itemBuilder: (_) => GalleryViewMode.values
          .map(
            (candidate) => PopupMenuItem<GalleryViewMode>(
              value: candidate,
              child: Row(
                children: [
                  Icon(_icon(candidate), size: 17),
                  const SizedBox(width: 9),
                  Text(_label(candidate)),
                  if (candidate == mode) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 16),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: _GalleryModeButton(
        icon: _icon(mode),
        label: _label(mode),
        active: mode == GalleryViewMode.masonry,
      ),
    );
  }

  static String _label(GalleryViewMode mode) => switch (mode) {
        GalleryViewMode.fixed => '固定比率',
        GalleryViewMode.masonry => 'メイソンリー',
      };

  static IconData _icon(GalleryViewMode mode) => switch (mode) {
        GalleryViewMode.fixed => Icons.grid_view,
        GalleryViewMode.masonry => Icons.view_quilt_outlined,
      };
}

class _GalleryModeButton extends StatelessWidget {
  const _GalleryModeButton({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
