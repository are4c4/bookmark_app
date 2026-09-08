import 'package:flutter/material.dart';

import '../domain/object_identity_search.dart';
import '../features/database/presentation/widgets/system_object_list_media.dart';
import '../services/bookmark_image_relation_service.dart';

class BookmarkCreateImagePickerResult {
  const BookmarkCreateImagePickerResult({
    required this.selectedImages,
    required this.coverImageObjectId,
  });

  final List<ObjectIdentitySearchResult> selectedImages;
  final int? coverImageObjectId;

  Set<int> get selectedObjectIds =>
      selectedImages.map((image) => image.objectId).toSet();
}

Future<BookmarkCreateImagePickerResult?> showBookmarkCreateImagePicker({
  required BuildContext context,
  required BookmarkImageRelationService service,
  required int workspaceId,
  Iterable<ObjectIdentitySearchResult> initiallySelected = const [],
  int? initialCoverImageObjectId,
}) =>
    showDialog<BookmarkCreateImagePickerResult>(
      context: context,
      builder: (_) => BookmarkCreateImagePickerDialog(
        service: service,
        workspaceId: workspaceId,
        initiallySelected: initiallySelected,
        initialCoverImageObjectId: initialCoverImageObjectId,
      ),
    );

class BookmarkCreateImagePickerDialog extends StatefulWidget {
  const BookmarkCreateImagePickerDialog({
    super.key,
    required this.service,
    required this.workspaceId,
    this.initiallySelected = const [],
    this.initialCoverImageObjectId,
  });

  final BookmarkImageRelationService service;
  final int workspaceId;
  final Iterable<ObjectIdentitySearchResult> initiallySelected;
  final int? initialCoverImageObjectId;

  @override
  State<BookmarkCreateImagePickerDialog> createState() =>
      _BookmarkCreateImagePickerDialogState();
}

class _BookmarkCreateImagePickerDialogState
    extends State<BookmarkCreateImagePickerDialog> {
  final _searchController = TextEditingController();
  final Map<int, ObjectIdentitySearchResult> _known = {};
  final Set<int> _selectedIds = {};
  List<ObjectIdentitySearchResult> _visible = const [];
  int? _coverImageObjectId;
  bool _loading = false;
  String? _errorMessage;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    for (final image in widget.initiallySelected) {
      _known[image.objectId] = image;
      _selectedIds.add(image.objectId);
    }
    final cover = widget.initialCoverImageObjectId;
    _coverImageObjectId = cover != null && _selectedIds.contains(cover)
        ? cover
        : null;
    Future<void>.microtask(() => _search(''));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final results = await widget.service.searchAvailableImages(
        workspaceId: widget.workspaceId,
        query: query,
      );
      if (!mounted || requestId != _requestId) return;
      for (final result in results) {
        _known[result.objectId] = result;
      }
      setState(() {
        _visible = List.unmodifiable(results);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _visible = const [];
        _loading = false;
        _errorMessage = 'Imagesを読み込めませんでした。';
      });
    }
  }

  void _toggle(ObjectIdentitySearchResult image) {
    setState(() {
      _known[image.objectId] = image;
      if (!_selectedIds.remove(image.objectId)) {
        _selectedIds.add(image.objectId);
      } else if (_coverImageObjectId == image.objectId) {
        _coverImageObjectId = null;
      }
    });
  }

  void _setCover(ObjectIdentitySearchResult image) {
    setState(() {
      _known[image.objectId] = image;
      _selectedIds.add(image.objectId);
      _coverImageObjectId = image.objectId;
    });
  }

  void _clear() {
    setState(() {
      _selectedIds.clear();
      _coverImageObjectId = null;
    });
  }

  void _save() {
    final selected = _selectedIds
        .map((id) => _known[id])
        .whereType<ObjectIdentitySearchResult>()
        .toList()
      ..sort((left, right) => left.objectId.compareTo(right.objectId));
    Navigator.pop(
      context,
      BookmarkCreateImagePickerResult(
        selectedImages: List.unmodifiable(selected),
        coverImageObjectId: _coverImageObjectId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Imagesから選択')),
          Text(
            '${_selectedIds.length}件選択',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 520,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('bookmark-create-image-picker-search'),
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: 'Imageを検索',
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      )
                    : null,
              ),
              onChanged: _search,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
                    key: const ValueKey('bookmark-create-image-picker-error'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _visible.isEmpty
                  ? Center(child: Text(_loading ? '読み込み中…' : 'Imageがありません'))
                  : ListView.builder(
                      itemCount: _visible.length,
                      itemBuilder: (context, index) {
                        final image = _visible[index];
                        final selected = _selectedIds.contains(image.objectId);
                        final cover = _coverImageObjectId == image.objectId;
                        return ListTile(
                          key: ValueKey(
                            'bookmark-create-image-picker-${image.objectId}',
                          ),
                          leading: SizedBox(
                            width: 44,
                            height: 44,
                            child: SystemObjectListMedia(
                              database: widget.service.database,
                              objectStore: widget.service.objectStore,
                              workspaceId: widget.workspaceId,
                              objectTypeId: image.objectType.id,
                              objectId: image.objectId,
                              size: 44,
                            ),
                          ),
                          title: Text(image.canonicalTitle),
                          subtitle:
                              image.aliasContext == null ? null : Text(image.aliasContext!),
                          onTap: () => _toggle(image),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: ValueKey(
                                  'bookmark-create-image-cover-${image.objectId}',
                                ),
                                tooltip: cover ? 'カバー画像' : 'カバーに設定',
                                onPressed: () => _setCover(image),
                                icon: Icon(
                                  cover
                                      ? Icons.photo_size_select_actual
                                      : Icons.photo_size_select_actual_outlined,
                                  size: 19,
                                ),
                              ),
                              Checkbox(
                                value: selected,
                                onChanged: (_) => _toggle(image),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _selectedIds.isEmpty ? null : _clear,
          child: const Text('クリア'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const ValueKey('bookmark-create-image-picker-save'),
          onPressed: _save,
          child: const Text('選択'),
        ),
      ],
    );
  }
}
