import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../services/image_visual_resolver.dart';
import '../services/person_profile_image_relation_service.dart';
import 'object_relation_picker_dialog.dart';

typedef PersonProfileImagePlaceholderBuilder = Widget Function(
  BuildContext context,
);

class PersonProfileImageMedia extends StatefulWidget {
  const PersonProfileImageMedia({
    super.key,
    required this.service,
    required this.workspaceId,
    required this.personId,
    required this.revision,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.clipOval = false,
    this.placeholderBuilder,
    this.imageBuilder,
  });

  final PersonProfileImageRelationService service;
  final int workspaceId;
  final int personId;
  final int revision;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool clipOval;
  final PersonProfileImagePlaceholderBuilder? placeholderBuilder;
  final Widget Function(BuildContext context, String filePath)? imageBuilder;

  @override
  State<PersonProfileImageMedia> createState() => _PersonProfileImageMediaState();
}

class _PersonProfileImageMediaState extends State<PersonProfileImageMedia> {
  late Future<ImageManagedVisual?> _visual;

  @override
  void initState() {
    super.initState();
    _visual = _load();
  }

  @override
  void didUpdateWidget(covariant PersonProfileImageMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.personId != widget.personId ||
        oldWidget.revision != widget.revision) {
      _visual = _load();
    }
  }

  Future<ImageManagedVisual?> _load() async {
    final state = await widget.service.load(
      workspaceId: widget.workspaceId,
      personId: widget.personId,
    );
    final imageObjectId = state.selectedImageObjectId;
    if (imageObjectId == null) return null;
    return ImageVisualResolver(
      widget.service.objectStore,
      pathResolver: widget.service.database.pathResolver,
      probeMissingGeometry: false,
    ).resolveManaged(
      imageObjectTypeId: state.imageObjectType.id,
      imageObjectId: imageObjectId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageManagedVisual?>(
      future: _visual,
      builder: (context, snapshot) {
        final visual = snapshot.data;
        final child = visual == null
            ? _placeholder(context)
            : _image(context, visual.filePath);
        final sized = SizedBox(
          key: ValueKey('person-profile-image-media-${widget.personId}'),
          width: widget.width,
          height: widget.height,
          child: child,
        );
        return widget.clipOval ? ClipOval(child: sized) : sized;
      },
    );
  }

  Widget _image(BuildContext context, String path) {
    final builder = widget.imageBuilder;
    if (builder != null) return builder(context, path);
    return Image.file(
      File(path),
      width: double.infinity,
      height: double.infinity,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final builder = widget.placeholderBuilder;
    if (builder != null) return builder(context);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: const Center(child: Icon(Icons.person_outline, size: 42)),
    );
  }
}

class PersonProfileImageEditor extends StatefulWidget {
  const PersonProfileImageEditor({
    super.key,
    required this.service,
    required this.workspaceId,
    required this.person,
    required this.revision,
    required this.onChanged,
  });

  final PersonProfileImageRelationService service;
  final int workspaceId;
  final Person person;
  final int revision;
  final VoidCallback onChanged;

  @override
  State<PersonProfileImageEditor> createState() =>
      _PersonProfileImageEditorState();
}

class _PersonProfileImageEditorState extends State<PersonProfileImageEditor> {
  late Future<PersonProfileImageRelationState> _state;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _state = _load();
  }

  @override
  void didUpdateWidget(covariant PersonProfileImageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.person.id != widget.person.id ||
        oldWidget.revision != widget.revision) {
      _state = _load();
    }
  }

  Future<PersonProfileImageRelationState> _load() => widget.service.load(
        workspaceId: widget.workspaceId,
        personId: widget.person.id,
      );

  void _reload() {
    if (!mounted) return;
    setState(() => _state = _load());
  }

  Future<void> _edit(PersonProfileImageRelationState state) async {
    final result = await showObjectRelationPickerDialog(
      context: context,
      selection: state.relation,
      onSearch: ({required context, required query}) =>
          widget.service.searchImages(state: state, query: query),
    );
    if (result == null) return;
    final selected = result.selectedObjectIds.toList(growable: false);
    if (selected.length > 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィール画像を更新できませんでした。')),
      );
      return;
    }
    await _mutate(
      state,
      selected.isEmpty ? null : selected.single,
    );
  }

  Future<void> _clear(PersonProfileImageRelationState state) =>
      _mutate(state, null);

  Future<void> _mutate(
    PersonProfileImageRelationState state,
    int? imageObjectId,
  ) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      if (imageObjectId == null) {
        await widget.service.clearProfileImage(
          workspaceId: state.workspaceId,
          personId: state.personId,
        );
      } else {
        await widget.service.setProfileImage(
          workspaceId: state.workspaceId,
          personId: state.personId,
          imageObjectId: imageObjectId,
        );
      }
      widget.onChanged();
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィール画像を更新できませんでした。')),
      );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<PersonProfileImageRelationState?>(
      future: _state,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 220,
            child: Center(
              child: Text(
                'プロフィール画像を読み込めませんでした。',
                style: TextStyle(color: scheme.error),
              ),
            ),
          );
        }
        final state = snapshot.data!;
        final hasImage = state.selectedImageObjectId != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('person-profile-image-edit'),
                onTap: _mutating ? null : () => _edit(state),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PersonProfileImageMedia(
                      service: widget.service,
                      workspaceId: widget.workspaceId,
                      personId: widget.person.id,
                      revision: widget.revision,
                      width: double.infinity,
                      height: 220,
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: .92),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_camera_outlined, size: 16),
                              const SizedBox(width: 5),
                              Text(
                                hasImage ? '画像を変更' : '画像を追加',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasDiagnostics)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '保存されているプロフィール画像Relationに問題があります。',
                  style: TextStyle(fontSize: 11.5, color: scheme.error),
                ),
              ),
            if (hasImage)
              TextButton.icon(
                onPressed: _mutating ? null : () => _clear(state),
                icon: const Icon(Icons.close, size: 15),
                label: const Text('画像を解除'),
              ),
          ],
        );
      },
    );
  }
}
