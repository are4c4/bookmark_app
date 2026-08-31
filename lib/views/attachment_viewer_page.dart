import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';

import '../data/app_database.dart';
import '../data/bookmark_attachment_store.dart';
import '../data/pdf_annotation_store.dart';

enum _PdfLayoutMode { continuous, single, facing }

class AttachmentViewerPage extends StatelessWidget {
  const AttachmentViewerPage({
    super.key,
    required this.attachment,
    required this.database,
  });

  final BookmarkAttachment attachment;
  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    if (attachment.isPdf) {
      return _PdfAttachmentViewer(attachment: attachment, database: database);
    }
    if (attachment.isVideo) {
      return _VideoAttachmentViewer(attachment: attachment);
    }
    return Scaffold(
      appBar: AppBar(title: Text(attachment.fileName)),
      body: const Center(child: Text('このファイル形式はアプリ内表示に対応していません')),
    );
  }
}

class _PdfAttachmentViewer extends StatefulWidget {
  const _PdfAttachmentViewer({required this.attachment, required this.database});

  final BookmarkAttachment attachment;
  final AppDatabase database;

  @override
  State<_PdfAttachmentViewer> createState() => _PdfAttachmentViewerState();
}

class _PdfAttachmentViewerState extends State<_PdfAttachmentViewer> {
  final _controller = PdfViewerController();
  final _searchController = TextEditingController();
  late final PdfAnnotationStore _annotationStore;
  PdfTextSearcher? _searcher;
  _PdfLayoutMode _layoutMode = _PdfLayoutMode.continuous;
  bool _rightToLeft = false;
  bool _searchVisible = false;
  String _selectedText = '';
  int _selectedPage = 1;
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    _annotationStore = PdfAnnotationStore(widget.database);
    _annotationStore.initialize();
  }

  @override
  void dispose() {
    _searcher?.dispose();
    _searchController.dispose();
    _controller.dispose();
    _annotationStore.dispose();
    super.dispose();
  }

  PdfPageLayout _horizontalPages(List<PdfPage> pages, PdfViewerParams params) {
    final height = pages.fold(0.0, (value, page) => math.max(value, page.height)) + params.margin * 2;
    final layouts = List<Rect>.filled(pages.length, Rect.zero);
    var x = params.margin;
    final order = _rightToLeft
        ? Iterable<int>.generate(pages.length).toList().reversed
        : Iterable<int>.generate(pages.length);
    for (final index in order) {
      final page = pages[index];
      layouts[index] = Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height);
      x += page.width + params.margin;
    }
    return PdfPageLayout(pageLayouts: layouts, documentSize: Size(x, height));
  }

  PdfPageLayout _facingPages(List<PdfPage> pages, PdfViewerParams params) {
    final width = pages.fold(0.0, (value, page) => math.max(value, page.width));
    final layouts = <Rect>[];
    const coverOffset = 1;
    var y = params.margin;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final pos = i + coverOffset;
      final isLeft = _rightToLeft ? (pos & 1) == 1 : (pos & 1) == 0;
      final otherSide = (pos ^ 1) - coverOffset;
      final h = 0 <= otherSide && otherSide < pages.length
          ? math.max(page.height, pages[otherSide].height)
          : page.height;
      layouts.add(
        Rect.fromLTWH(
          isLeft ? width + params.margin - page.width : params.margin * 2 + width,
          y + (h - page.height) / 2,
          page.width,
          page.height,
        ),
      );
      if ((pos & 1) == 1 || i + 1 == pages.length) y += h + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: layouts,
      documentSize: Size((params.margin + width) * 2 + params.margin, y),
    );
  }

  PdfPageLayoutFunction? get _layoutPages => switch (_layoutMode) {
        _PdfLayoutMode.continuous => null,
        _PdfLayoutMode.single => _horizontalPages,
        _PdfLayoutMode.facing => _facingPages,
      };

  void _changeLayout(_PdfLayoutMode mode) {
    setState(() => _layoutMode = mode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.isReady) _controller.invalidate();
    });
  }

  void _toggleReadingDirection() {
    setState(() => _rightToLeft = !_rightToLeft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.isReady) _controller.invalidate();
    });
  }

  Future<void> _goRelative(int delta) async {
    if (!_controller.isReady || _pageCount == 0) return;
    final current = _controller.pageNumber ?? 1;
    final step = _layoutMode == _PdfLayoutMode.facing ? 2 : 1;
    final logicalDelta = _rightToLeft ? -delta : delta;
    final target = (current + logicalDelta * step).clamp(1, _pageCount);
    await _controller.goToPage(pageNumber: target);
  }

  void _startSearch(String value) {
    final query = value.trim();
    final searcher = _searcher;
    if (searcher == null) return;
    if (query.isEmpty) {
      searcher.resetTextSearch();
    } else {
      searcher.startTextSearch(query, caseInsensitive: true);
    }
  }

  Future<void> _addAnnotation(String kind) async {
    if (_selectedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF本文をドラッグして選択してから追加してください')),
      );
      return;
    }
    var note = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(kind == 'highlight' ? 'ハイライトを保存' : '注釈を追加'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('p.$_selectedPage  $_selectedText', maxLines: 5, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              TextFormField(
                autofocus: kind == 'note',
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'メモ（任意）'),
                onChanged: (value) => note = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存')),
        ],
      ),
    );
    if (saved != true) return;
    await _annotationStore.add(
      attachmentId: widget.attachment.id,
      pageNumber: _selectedPage,
      kind: kind,
      selectedText: _selectedText,
      note: note,
    );
  }

  Future<void> _showAnnotations() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .65,
        child: StreamBuilder<List<PdfAnnotationRecord>>(
          stream: _annotationStore.watchForAttachment(widget.attachment.id),
          builder: (context, snapshot) {
            final annotations = snapshot.data ?? const <PdfAnnotationRecord>[];
            if (annotations.isEmpty) return const Center(child: Text('ハイライト・注釈はまだありません'));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: annotations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final annotation = annotations[index];
                return ListTile(
                  leading: Icon(annotation.kind == 'highlight' ? Icons.highlight : Icons.sticky_note_2_outlined),
                  title: Text(annotation.selectedText, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([
                    'p.${annotation.pageNumber}',
                    if (annotation.note.isNotEmpty) annotation.note,
                  ].join(' · ')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _controller.goToPage(pageNumber: annotation.pageNumber);
                  },
                  trailing: IconButton(
                    tooltip: '削除',
                    icon: const Icon(Icons.delete_outline, size: 19),
                    onPressed: () => _annotationStore.remove(annotation.id),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _searchBar() {
    final searcher = _searcher;
    return SizedBox(
      width: 420,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _startSearch,
              decoration: const InputDecoration(hintText: 'PDF本文を検索…', prefixIcon: Icon(Icons.search, size: 18)),
            ),
          ),
          if (searcher != null) ...[
            AnimatedBuilder(
              animation: searcher,
              builder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Text('${searcher.matches.length}件', style: const TextStyle(fontSize: 12)),
              ),
            ),
            IconButton(tooltip: '前の一致', onPressed: searcher.goToPrevMatch, icon: const Icon(Icons.keyboard_arrow_up)),
            IconButton(tooltip: '次の一致', onPressed: searcher.goToNextMatch, icon: const Icon(Icons.keyboard_arrow_down)),
          ],
          IconButton(
            tooltip: '検索を閉じる',
            onPressed: () {
              _searchController.clear();
              searcher?.resetTextSearch();
              setState(() => _searchVisible = false);
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searcher = _searcher;
    return Scaffold(
      appBar: AppBar(
        title: _searchVisible ? _searchBar() : Text(widget.attachment.fileName),
        actions: _searchVisible
            ? null
            : [
                IconButton(tooltip: '本文検索', onPressed: () => setState(() => _searchVisible = true), icon: const Icon(Icons.search)),
                PopupMenuButton<_PdfLayoutMode>(
                  tooltip: '表示方法',
                  initialValue: _layoutMode,
                  onSelected: _changeLayout,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _PdfLayoutMode.continuous, child: Text('縦スクロール')),
                    PopupMenuItem(value: _PdfLayoutMode.single, child: Text('1ページ')),
                    PopupMenuItem(value: _PdfLayoutMode.facing, child: Text('見開き')),
                  ],
                  icon: Icon(_layoutMode == _PdfLayoutMode.facing ? Icons.auto_stories_outlined : Icons.chrome_reader_mode_outlined),
                ),
                IconButton(
                  tooltip: _rightToLeft ? '右綴じ（右→左）' : '左綴じ（左→右）',
                  onPressed: _toggleReadingDirection,
                  icon: Icon(_rightToLeft ? Icons.format_textdirection_r_to_l : Icons.format_textdirection_l_to_r),
                ),
                IconButton(tooltip: '前へ', onPressed: () => _goRelative(-1), icon: const Icon(Icons.chevron_left)),
                IconButton(tooltip: '次へ', onPressed: () => _goRelative(1), icon: const Icon(Icons.chevron_right)),
                PopupMenuButton<String>(
                  tooltip: 'ハイライト・注釈',
                  onSelected: (value) {
                    if (value == 'highlight') _addAnnotation('highlight');
                    if (value == 'note') _addAnnotation('note');
                    if (value == 'list') _showAnnotations();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'highlight', child: Text('選択範囲をハイライトとして保存')),
                    PopupMenuItem(value: 'note', child: Text('選択範囲に注釈を追加')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'list', child: Text('ハイライト・注釈一覧')),
                  ],
                  icon: const Icon(Icons.edit_note),
                ),
              ],
      ),
      body: PdfViewer.file(
        widget.attachment.path,
        controller: _controller,
        params: PdfViewerParams(
          layoutPages: _layoutPages,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          pagePaintCallbacks: [
            if (searcher != null) searcher.pageTextMatchPaintCallback,
          ],
          textSelectionParams: PdfTextSelectionParams(
            enabled: true,
            onTextSelectionChange: (selection) async {
              final text = selection.getSelectedText();
              final range = _controller.textSelection.textSelectionPointRange;
              if (!mounted) return;
              setState(() {
                _selectedText = text;
                _selectedPage = range?.start.text.pageNumber ?? _controller.pageNumber ?? 1;
              });
            },
          ),
          onViewerReady: (document, controller) {
            _pageCount = document.pages.length;
            if (_searcher == null) {
              final created = PdfTextSearcher(controller);
              created.addListener(() {
                if (mounted) setState(() {});
              });
              setState(() => _searcher = created);
            }
          },
        ),
      ),
    );
  }
}

class _VideoAttachmentViewer extends StatefulWidget {
  const _VideoAttachmentViewer({required this.attachment});

  final BookmarkAttachment attachment;

  @override
  State<_VideoAttachmentViewer> createState() => _VideoAttachmentViewerState();
}

class _VideoAttachmentViewerState extends State<_VideoAttachmentViewer> {
  late final VideoPlayerController _controller;
  var _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.attachment.path));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _time(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${value.inMinutes}:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.attachment.fileName)),
      body: _error != null
          ? Center(child: Text('動画を開けませんでした:\n$_error'))
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final value = _controller.value;
                            final duration = value.duration;
                            final position = value.position > duration ? duration : value.position;
                            final max = duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
                            return Material(
                              color: Theme.of(context).colorScheme.surfaceContainerLow,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                                child: Column(
                                  children: [
                                    Slider(
                                      min: 0,
                                      max: max,
                                      value: position.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                                      onChanged: (v) => _controller.seekTo(Duration(milliseconds: v.round())),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: value.isPlaying ? '一時停止' : '再生',
                                          onPressed: () => value.isPlaying ? _controller.pause() : _controller.play(),
                                          icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                                        ),
                                        IconButton(
                                          tooltip: '10秒戻る',
                                          onPressed: () => _controller.seekTo(
                                            position - const Duration(seconds: 10) < Duration.zero
                                                ? Duration.zero
                                                : position - const Duration(seconds: 10),
                                          ),
                                          icon: const Icon(Icons.replay_10),
                                        ),
                                        IconButton(
                                          tooltip: '10秒進む',
                                          onPressed: () => _controller.seekTo(
                                            position + const Duration(seconds: 10) > duration
                                                ? duration
                                                : position + const Duration(seconds: 10),
                                          ),
                                          icon: const Icon(Icons.forward_10),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${_time(position)} / ${_time(duration)}'),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: value.volume == 0 ? 'ミュート解除' : 'ミュート',
                                          onPressed: () => _controller.setVolume(value.volume == 0 ? 1 : 0),
                                          icon: Icon(value.volume == 0 ? Icons.volume_off : Icons.volume_up),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
