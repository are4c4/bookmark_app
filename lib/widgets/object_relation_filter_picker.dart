import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/object_identity_search.dart';

typedef RelationFilterCandidateSearch =
    Future<List<ObjectIdentitySearchResult>> Function(String query);

/// Canonical Object picker used only for authoring Relation filter operands.
///
/// Display text is resolved from canonical Object identity while [onChanged]
/// continues to emit persisted Object ids. Missing/deleted ids stay visible as
/// explicit warning chips instead of being silently rebound to another Object.
class ObjectRelationFilterPicker extends StatefulWidget {
  const ObjectRelationFilterPicker({
    super.key,
    required this.selectedObjectIds,
    required this.searchCandidates,
    required this.onChanged,
  });

  final List<int> selectedObjectIds;
  final RelationFilterCandidateSearch searchCandidates;
  final ValueChanged<List<int>> onChanged;

  @override
  State<ObjectRelationFilterPicker> createState() =>
      _ObjectRelationFilterPickerState();
}

class _ObjectRelationFilterPickerState
    extends State<ObjectRelationFilterPicker> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<ObjectIdentitySearchResult> _candidates = const [];
  final Map<int, ObjectIdentitySearchResult> _resolvedById = {};
  bool _loading = false;
  bool _searchFailed = false;
  int _activeIndex = 0;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void didUpdateWidget(covariant ObjectRelationFilterPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchCandidates != widget.searchCandidates ||
        !_sameIds(oldWidget.selectedObjectIds, widget.selectedObjectIds)) {
      _search(_controller.text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _sameIds(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  Future<void> _search(String query) async {
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _searchFailed = false;
    });
    try {
      final candidates = await widget.searchCandidates(query);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _candidates = candidates;
        for (final candidate in candidates) {
          if (widget.selectedObjectIds.contains(candidate.objectId)) {
            _resolvedById[candidate.objectId] = candidate;
          }
        }
        if (candidates.isEmpty) {
          _activeIndex = 0;
        } else if (_activeIndex >= candidates.length) {
          _activeIndex = candidates.length - 1;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _candidates = const [];
        _activeIndex = 0;
        _loading = false;
        _searchFailed = true;
      });
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_candidates.isNotEmpty && _activeIndex < _candidates.length - 1) {
        setState(() => _activeIndex += 1);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_candidates.isNotEmpty && _activeIndex > 0) {
        setState(() => _activeIndex -= 1);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_candidates.isNotEmpty) _toggle(_candidates[_activeIndex]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _controller.clear();
      _search('');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggle(ObjectIdentitySearchResult candidate) {
    final next = [...widget.selectedObjectIds];
    if (!next.remove(candidate.objectId)) {
      next.add(candidate.objectId);
      _resolvedById[candidate.objectId] = candidate;
    }
    widget.onChanged(List<int>.unmodifiable(next));
  }

  void _remove(int objectId) {
    widget.onChanged(
      List<int>.unmodifiable(
        widget.selectedObjectIds.where((id) => id != objectId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.selectedObjectIds.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.selectedObjectIds.map((objectId) {
              final resolved = _resolvedById[objectId];
              return InputChip(
                key: ValueKey('relation-filter-selected-$objectId'),
                avatar: resolved == null
                    ? const Icon(Icons.warning_amber_rounded, size: 16)
                    : null,
                label: Text(
                  resolved?.canonicalTitle ?? '不明なObject #$objectId',
                ),
                onDeleted: () => _remove(objectId),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 8),
        ],
        Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKeyEvent,
          child: TextField(
            key: const ValueKey('relation-filter-search'),
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Objectを検索',
              hintText: '名前または別名',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    )
                  : _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '検索をクリア',
                          onPressed: () {
                            _controller.clear();
                            _search('');
                            _focusNode.requestFocus();
                          },
                          icon: const Icon(Icons.close),
                        ),
            ),
            onChanged: _search,
          ),
        ),
        if (_searchFailed) ...[
          const SizedBox(height: 6),
          Text(
            'Relation候補を読み込めませんでした。',
            key: const ValueKey('relation-filter-search-error'),
            style: TextStyle(color: scheme.error, fontSize: 12),
          ),
        ] else if (_candidates.isNotEmpty) ...[
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _candidates.length,
              itemBuilder: (context, index) {
                final candidate = _candidates[index];
                final selected =
                    widget.selectedObjectIds.contains(candidate.objectId);
                return Material(
                  color: index == _activeIndex
                      ? scheme.secondaryContainer.withValues(alpha: .45)
                      : Colors.transparent,
                  child: ListTile(
                    key: ValueKey(
                      'relation-filter-candidate-${candidate.objectId}',
                    ),
                    dense: true,
                    selected: selected,
                    leading: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 18,
                    ),
                    title: Text(candidate.canonicalTitle),
                    subtitle: candidate.aliasContext == null
                        ? null
                        : Text(candidate.aliasContext!),
                    onTap: () => _toggle(candidate),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
