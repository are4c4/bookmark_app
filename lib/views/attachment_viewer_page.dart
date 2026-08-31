import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';

import '../data/bookmark_attachment_store.dart';

class AttachmentViewerPage extends StatelessWidget {
  const AttachmentViewerPage({super.key, required this.attachment});

  final BookmarkAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.isPdf) {
      return Scaffold(
        appBar: AppBar(title: Text(attachment.fileName)),
        body: PdfViewer.file(attachment.path),
      );
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
                              aspectRatio: _controller.value.aspectRatio == 0
                                  ? 16 / 9
                                  : _controller.value.aspectRatio,
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
                            final max = duration.inMilliseconds <= 0
                                ? 1.0
                                : duration.inMilliseconds.toDouble();
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
                                          onPressed: () => value.isPlaying
                                              ? _controller.pause()
                                              : _controller.play(),
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
