import 'package:flutter/material.dart';

import '../data/relation_target_service.dart';
import '../domain/object_identity_search.dart';

typedef ObjectRelationPickerSearch = Future<List<ObjectIdentitySearchResult>>
    Function({
  required RelationSelectionContext context,
  required String query,
});
typedef ObjectRelationPickerQuickCreate = Future<int?> Function(String query);
typedef ObjectRelationPickerReload = Future<RelationSelectionContext> Function();
typedef ObjectRelationPickerQuickCreateLabel = String Function(String query);

class ObjectRelationPickerResult {
  const ObjectRelationPickerResult({
    required this.context,
    required this.selectedObjectIds,
  });

  /// Latest canonical context. This may differ from the initial context when a
  /// target Object was quick-created while the picker was open.
  final RelationSelectionContext context;
  final Set<int> selectedObjectIds;
}

Future<ObjectRelationPickerResult?> showObjectRelationPickerDialog({
  required BuildContext context,
  required RelationSelectionContext selection,
  required ObjectRelationPickerSearch onSearch,
  ObjectRelationPickerQuickCreate? onQuickCreate,
  ObjectRelationPickerReload? onReloadAfterQuickCreate,
  ObjectRelationPickerQuickCreateLabel? quickCreateLabel,
}) =>
    showDialog<ObjectRelationPickerResult>(
      context: context,
      builder: (_) => ObjectRelationPickerDialog(
        selection: selection,
        onSearch: onSearch,
        onQuickCreate: onQuickCreate,
        onReloadAfterQuickCreate: onReloadAfterQuickCreate,
        quickCreateLabel: quickCreateLabel,
      ),
    );

/// Generic Relation value picker with an optional refresh-safe quick-create
/// affordance.
///
/// This widget never persists a Relation or creates a target by itself. The host
/// supplies canonical search/reload/create callbacks. After quick-create the
/// picker *must* reload [RelationSelectionContext] and verifies the new Object is
/// part of the refreshed canonical candidate set before selecting it. The
/// returned result carries that refreshed context so `ObjectRelationEditorService
/// .save(...)` validates against current candidates rather than a stale snapshot.
class ObjectRelationPickerDialog extends StatefulWidget {
  const ObjectRelationPickerDialog({
    super.key,
    required this.selection,
    required this.onSearch,
    this.onQuickCreate,
    this.onReloadAfterQuickCreate,
    this.quickCreateLabel,
  }) : assert(
          (onQuickCreate == null) == (onReloadAfterQuickCreate == null),
          'Quick-create requires both create and canonical reload callbacks.',
        );

  final RelationSelectionContext selection;
  final ObjectRelationPickerSearch onSearch;
  final ObjectRelationPickerQuickCreate? onQuickCreate;
  final ObjectRelationPickerReload? onReloadAfterQuickCreate;
  final ObjectRelationPickerQuickCreateLabel? quickCreateLabel;

  @override
  State<ObjectRelationPickerDialog> createState() =>
      _ObjectRelationPickerDialogState();
}

class _ObjectRelationPickerDialogState extends State<ObjectRelationPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  late RelationSelectionContext _selection;
  late Set<int> _selectedIds;
  List<ObjectIdentitySearchResult> _visible = const [];
  String? _errorMessage;
  bool _searching = false;
  bool _creating = false;
  int _searchRequestId = 0;

  bool get _quickCreateEnabled =>
      widget.onQuickCreate != null && widget.onReloadAfterQuickCreate != null;

  @override
  void initState() {
    super.initState();
    _selection = widget.selection;
    _selectedIds = widget.selection.selectedObjectIds.toSet();
    Future<void>.microtask(() => _runSearch(''));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final requestId = ++_searchRequestId;
    if (mounted) {
      setState(() {
        _searching = true;
        _errorMessage = null;
      });
    }
    try {
      final next = await widget.onSearch(
        context: _selection,
        query: query,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _visible = List<ObjectIdentitySearchResult>.unmodifiable(next);
        _searching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _visible = const [];
        _searching = false;
        _errorMessage = 'Objectを検索できませんでした。';
      });
    }
  }

  Future<void> _quickCreate() async {
    final rawQuery = _searchController.text.trim();
    final create = widget.onQuickCreate;
    final reload = widget.onReloadAfterQuickCreate;
    if (!_quickCreateEnabled || rawQuery.isEmpty || _creating) return;
    setState(() {
      _creating = true;
      _errorMessage = null;
    });
    try {
      final createdId = await create!(rawQuery);
      if (!mounted || createdId == null) return;
      final refreshed = await reload!();
      if (!mounted) return;
      final candidateIds = refreshed.candidates.map((object) => object.id).toSet();
      if (!candidateIds.contains(createdId)) {
        setState(() {
          _errorMessage = '作成したObjectをRelation候補として確認できませんでした。';
        });
        return;
      }

      setState(() {
        _selection = refreshed;
        if (!refreshed.property.allowsMultipleRelations) {
          _selectedIds.clear();
        }
        _selectedIds.add(createdId);
        _searchController.clear();
      });
      await _runSearch('');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Objectを作成できませんでした。');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _toggle(ObjectIdentitySearchResult candidate) {
    setState(() {
      if (!_selectedIds.remove(candidate.objectId)) {
        if (!_selection.property.allowsMultipleRelations) {
          _selectedIds.clear();
        }
        _selectedIds.add(candidate.objectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _searchController.text.trim();
    final quickCreateLabel = widget.quickCreateLabel?.call(query) ??
        (query.isEmpty ? 'Objectを作成' : '「$query」を作成');

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      title: Row(
        children: [
          Expanded(child: Text(_selection.property.name)),
          Text(
            '${_selectedIds.length}件選択',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 500,
        child: Column(
          children: [
            if (_selection.missingTargetObjectIds.isNotEmpty ||
                _selection.hasCardinalityViolation)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  [
                    if (_selection.missingTargetObjectIds.isNotEmpty)
                      '見つからないObject: ${_selection.missingTargetObjectIds.join(', ')}',
                    if (_selection.hasCardinalityViolation)
                      '単一Relationに複数の値が保存されています。明示的に選び直して保存してください。',
                  ].join('\n'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                key: const ValueKey('object-relation-picker-search'),
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Objectを検索',
                  suffixIcon: _searching
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
                onChanged: (value) {
                  setState(() {});
                  _runSearch(value);
                },
                onSubmitted: (_) {
                  if (_quickCreateEnabled) _quickCreate();
                },
              ),
            ),
            if (_quickCreateEnabled && query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('object-relation-picker-quick-create'),
                    onPressed: _creating ? null : _quickCreate,
                    icon: _creating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: Text(quickCreateLabel),
                  ),
                ),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
                    key: const ValueKey('object-relation-picker-error'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: _visible.isEmpty
                  ? Center(
                      child: Text(
                        _searching ? '検索中…' : '該当するObjectがありません',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _visible.length,
                      itemBuilder: (context, index) {
                        final candidate = _visible[index];
                        final selected = _selectedIds.contains(candidate.objectId);
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _selection.property.allowsMultipleRelations
                                ? (selected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank)
                                : (selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked),
                            size: 19,
                          ),
                          title: Text(candidate.canonicalTitle),
                          subtitle: candidate.aliasContext == null
                              ? null
                              : Text(candidate.aliasContext!),
                          onTap: () => _toggle(candidate),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => setState(_selectedIds.clear),
          child: const Text('クリア'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const ValueKey('object-relation-picker-save'),
          onPressed: () => Navigator.pop(
            context,
            ObjectRelationPickerResult(
              context: _selection,
              selectedObjectIds: Set<int>.unmodifiable(_selectedIds),
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
