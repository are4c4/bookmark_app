import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/object_store.dart';
import '../domain/object_model.dart';
import '../services/bookmark_image_relation_service.dart';
import '../services/bookmark_image_relation_service_factory.dart';
import '../services/image_visual_resolver.dart';
import 'object_relation_picker_dialog.dart';

/// Bookmark detail image UI backed by canonical Image Objects and Relations.
///
/// Legacy Photo rows remain a read-only compatibility fallback only when the
/// Bookmark has not yet been mirrored into the Object system. All editable
/// production paths use `Images` / `Cover Image` Relations.
class BookmarkImageRelationSection extends StatefulWidget {
  const BookmarkImageRelationSection({
    super.key,
    required this.repository,
    required this.bookmark,
    this.onFilterByLegacyPhoto,
    this.onChanged,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final ValueChanged<PhotoRecord>? onFilterByLegacyPhoto;
  final VoidCallback? onChanged;

  @override
  State<BookmarkImageRelationSection> createState() =>
      _BookmarkImageRelationSectionState();
}

class _BookmarkImageRelationSectionState
    extends State<BookmarkImageRelationSection> {
  late BookmarkImageRelationService _service;
  late Future<BookmarkImageRelationState?> _state;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _resetService();
  }

  @override
  void didUpdateWidget(covariant BookmarkImageRelationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.bookmark.id != widget.bookmark.id) {
      _resetService();
    }
  }

  void _resetService() {
    _service = createBookmarkImageRelationService(widget.repository);
    _state = _load();
  }

  Future<BookmarkImageRelationState?> _load() => _service.load(
        workspaceId: widget.repository.workspaceId,
        bookmarkId: widget.bookmark.id,
      );

  void _reload() {
    if (!mounted) return;
    setState(() => _state = _load());
  }

  Future<void> _editImages(BookmarkImageRelationState state) async {
    final result = await showObjectRelationPickerDialog(
      context: context,
      selection: state.images,
      onSearch: ({required context, required query}) =>
          _service.searchImages(state: state, query: query),
    );
    if (result == null) return;
    await _mutate(
      () => _service.saveImages(
        state: state,
        selectedObjectIds: result.selectedObjectIds,
      ),
    );
  }

  Future<void> _setCover(
    BookmarkImageRelationState state,
    int imageObjectId,
  ) =>
      _mutate(
        () => _service.setCover(
          state: state,
          imageObjectId: imageObjectId,
        ),
      );

  Future<void> _clearCover(BookmarkImageRelationState state) =>
      _mutate(() => _service.clearCover(state: state));

  Future<void> _detach(
    BookmarkImageRelationState state,
    int imageObjectId,
  ) =>
      _mutate(
        () => _service.detachImage(
          state: state,
          imageObjectId: imageObjectId,
        ),
      );

  Future<void> _mutate(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
      widget.onChanged?.call();
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像Relationを更新できませんでした。')),
      );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BookmarkImageRelationState?>(
      future: _state,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loading(context);
        }
        if (snapshot.hasError) {
          return _error(context);
        }
        final state = snapshot.data;
        if (state == null) {
          return _legacyFallback(context);
        }
        return _canonical(context, state);
      },
    );
  }

  Widget _header(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _loading(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, title: '関連画像'),
          const SizedBox(height: 10),
          const SizedBox(
            key: ValueKey('bookmark-image-relation-loading'),
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ],
      );

  Widget _error(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          context,
          title: '関連画像',
          trailing: IconButton(
            tooltip: '再読み込み',
            visualDensity: VisualDensity.compact,
            onPressed: _reload,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '画像Relationを読み込めませんでした。',
          key: const ValueKey('bookmark-image-relation-error'),
          style: TextStyle(fontSize: 12.5, color: scheme.error),
        ),
      ],
    );
  }

  Widget _canonical(
    BuildContext context,
    BookmarkImageRelationState state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final images = state.selectedImages;
    return Column(
      key: const ValueKey('bookmark-image-relation-canonical'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          context,
          title: '関連画像',
          trailing: IconButton(
            key: const ValueKey('bookmark-image-relation-edit'),
            tooltip: 'Imagesから選択',
            visualDensity: VisualDensity.compact,
            onPressed: _mutating ? null : () => _editImages(state),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
          ),
        ),
        if (state.hasDiagnostics) ...[
          const SizedBox(height: 6),
          Text(
            '保存されている画像Relationに問題があります。選択画面で確認してください。',
            key: const ValueKey('bookmark-image-relation-diagnostic'),
            style: TextStyle(fontSize: 11.5, color: scheme.error),
          ),
        ],
        const SizedBox(height: 10),
        if (images.isEmpty)
          Text(
            '関連画像はありません',
            style: TextStyle(fontSize: 12.5, color: muted),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final image = images[index];
                return _canonicalCard(context, state, image);
              },
            ),
          ),
      ],
    );
  }

  Widget _canonicalCard(
    BuildContext context,
    BookmarkImageRelationState state,
    AppObject image,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isCover = state.validCoverImageObjectId == image.id;
    return SizedBox(
      key: ValueKey('bookmark-image-relation-card-${image.id}'),
      width: 126,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CanonicalImageThumbnail(
                    database: _service.database,
                    objectStore: _service.objectStore,
                    imageObjectTypeId: state.imageObjectType.id,
                    imageObjectId: image.id,
                  ),
                  if (isCover)
                    const Positioned(
                      top: 5,
                      left: 5,
                      child: Icon(Icons.photo_size_select_actual, size: 15),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        image.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: ValueKey('bookmark-image-relation-menu-${image.id}'),
                    padding: EdgeInsets.zero,
                    iconSize: 17,
                    enabled: !_mutating,
                    onSelected: (value) {
                      if (value == 'cover') _setCover(state, image.id);
                      if (value == 'clear') _clearCover(state);
                      if (value == 'detach') _detach(state, image.id);
                    },
                    itemBuilder: (_) => [
                      if (!isCover)
                        const PopupMenuItem(
                          value: 'cover',
                          child: Text('カバーにする'),
                        ),
                      if (isCover)
                        const PopupMenuItem(
                          value: 'clear',
                          child: Text('カバー解除'),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'detach',
                        child: Text('関連を解除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legacyFallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final photos = widget.bookmark.photos;
    return Column(
      key: const ValueKey('bookmark-image-relation-legacy-fallback'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context, title: '関連写真（互換表示）'),
        const SizedBox(height: 6),
        Text(
          'Object同期前の写真は読み取り専用で表示しています。',
          style: TextStyle(fontSize: 11.5, color: muted),
        ),
        const SizedBox(height: 10),
        if (photos.isEmpty)
          Text(
            '関連写真はありません',
            style: TextStyle(fontSize: 12.5, color: muted),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photo = photos[index];
                final isCover = widget.bookmark.coverPhoto?.id == photo.id;
                return SizedBox(
                  width: 126,
                  child: Material(
                    color: scheme.surface,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onFilterByLegacyPhoto == null
                          ? null
                          : () => widget.onFilterByLegacyPhoto!(photo),
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(photo.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _imagePlaceholder(context),
                                ),
                                if (isCover)
                                  const Positioned(
                                    top: 5,
                                    left: 5,
                                    child: Icon(
                                      Icons.photo_size_select_actual,
                                      size: 15,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 30,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 7),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  photo.title ?? '写真',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(alpha: .55),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: scheme.onSurfaceVariant.withValues(alpha: .6),
        ),
      ),
    );
  }
}

class _CanonicalImageThumbnail extends StatefulWidget {
  const _CanonicalImageThumbnail({
    required this.database,
    required this.objectStore,
    required this.imageObjectTypeId,
    required this.imageObjectId,
  });

  final AppDatabase database;
  final ObjectStore objectStore;
  final int imageObjectTypeId;
  final int imageObjectId;

  @override
  State<_CanonicalImageThumbnail> createState() =>
      _CanonicalImageThumbnailState();
}

class _CanonicalImageThumbnailState extends State<_CanonicalImageThumbnail> {
  late Future<ImageManagedVisual?> _visual;

  @override
  void initState() {
    super.initState();
    _visual = _resolve();
  }

  @override
  void didUpdateWidget(covariant _CanonicalImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.objectStore != widget.objectStore ||
        oldWidget.imageObjectTypeId != widget.imageObjectTypeId ||
        oldWidget.imageObjectId != widget.imageObjectId) {
      _visual = _resolve();
    }
  }

  Future<ImageManagedVisual?> _resolve() => ImageVisualResolver(
        widget.objectStore,
        pathResolver: widget.database.pathResolver,
      ).resolveManaged(
        imageObjectTypeId: widget.imageObjectTypeId,
        imageObjectId: widget.imageObjectId,
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageManagedVisual?>(
      future: _visual,
      builder: (context, snapshot) {
        final path = snapshot.data?.filePath;
        if (path == null) return _placeholder(context);
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(context),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(alpha: .55),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: scheme.onSurfaceVariant.withValues(alpha: .6),
        ),
      ),
    );
  }
}
