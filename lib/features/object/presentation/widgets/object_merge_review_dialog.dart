import 'package:flutter/material.dart';

import '../../../../domain/object_merge_contract.dart';
import '../../../../domain/object_merge_state_materializer.dart';

class ObjectMergeReviewResult {
  const ObjectMergeReviewResult({required this.survivingObjectId});

  final int survivingObjectId;
}

typedef ObjectMergePrepareCallback = Future<ObjectMergePreparedState> Function({
  required int survivorObjectId,
  required int retiredObjectId,
});

typedef ObjectMergeFinalizeCallback = Future<int> Function({
  required ObjectMergePreparedState prepared,
  required ObjectMergePlan plan,
});

class ObjectMergeReviewDialog extends StatefulWidget {
  const ObjectMergeReviewDialog({
    super.key,
    required this.currentObjectId,
    required this.currentTitle,
    required this.candidateObjectId,
    required this.candidateTitle,
    required this.propertyNames,
    required this.onPrepare,
    required this.onFinalize,
  });

  final int currentObjectId;
  final String currentTitle;
  final int candidateObjectId;
  final String candidateTitle;
  final Map<int, String> propertyNames;
  final ObjectMergePrepareCallback onPrepare;
  final ObjectMergeFinalizeCallback onFinalize;

  @override
  State<ObjectMergeReviewDialog> createState() =>
      _ObjectMergeReviewDialogState();
}

class _ObjectMergeReviewDialogState extends State<ObjectMergeReviewDialog> {
  bool _currentSurvives = true;
  bool _loading = true;
  bool _finalizing = false;
  ObjectMergePreparedState? _prepared;
  Map<String, ObjectMergeDecision> _decisions =
      const <String, ObjectMergeDecision>{};
  String? _errorText;

  int get _survivorObjectId =>
      _currentSurvives ? widget.currentObjectId : widget.candidateObjectId;

  int get _retiredObjectId =>
      _currentSurvives ? widget.candidateObjectId : widget.currentObjectId;

  String get _survivorTitle =>
      _currentSurvives ? widget.currentTitle : widget.candidateTitle;

  String get _retiredTitle =>
      _currentSurvives ? widget.candidateTitle : widget.currentTitle;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final survivorObjectId = _survivorObjectId;
    final retiredObjectId = _retiredObjectId;
    setState(() {
      _loading = true;
      _prepared = null;
      _decisions = const <String, ObjectMergeDecision>{};
      _errorText = null;
    });
    try {
      final prepared = await widget.onPrepare(
        survivorObjectId: survivorObjectId,
        retiredObjectId: retiredObjectId,
      );
      if (!mounted ||
          survivorObjectId != _survivorObjectId ||
          retiredObjectId != _retiredObjectId) {
        return;
      }
      setState(() {
        _prepared = prepared;
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          survivorObjectId != _survivorObjectId ||
          retiredObjectId != _retiredObjectId) {
        return;
      }
      setState(() {
        _loading = false;
        _errorText = '統合内容を確認できませんでした。Objectの状態を確認して再試行してください。';
      });
    }
  }

  Future<void> _selectSurvivor(bool currentSurvives) async {
    if (_currentSurvives == currentSurvives || _finalizing) return;
    setState(() => _currentSurvives = currentSurvives);
    await _prepare();
  }

  ObjectMergePlan? get _plan {
    final prepared = _prepared;
    if (prepared == null) return null;
    try {
      return prepared.plan(decisions: _decisions);
    } catch (_) {
      return null;
    }
  }

  Future<void> _finalize() async {
    final prepared = _prepared;
    final plan = _plan;
    if (prepared == null || plan == null || !plan.isExecutable || _finalizing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Objectを統合しますか？'),
        content: Text(
          '「$_survivorTitle」（#$_survivorObjectId）を残し、'
          '「$_retiredTitle」（#$_retiredObjectId）を統合します。'
          '統合されるObjectのIDは残すObjectへリダイレクトされます。',
        ),
        actions: [
          TextButton(
            key: const ValueKey('object-merge-confirm-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('戻る'),
          ),
          FilledButton(
            key: const ValueKey('object-merge-confirm-submit'),
            autofocus: false,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('統合する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _finalizing = true;
      _errorText = null;
    });
    try {
      final survivingObjectId = await widget.onFinalize(
        prepared: prepared,
        plan: plan,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        ObjectMergeReviewResult(survivingObjectId: survivingObjectId),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _finalizing = false);
      await _prepare();
      if (!mounted) return;
      setState(() {
        _errorText =
            '統合前にObjectまたはRelationの状態が変わった可能性があります。内容をもう一度確認してください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepared = _prepared;
    final plan = _plan;
    final requirements = prepared?.preview.requirements
            .where((requirement) => requirement.requiresDecision)
            .toList(growable: false) ??
        const <ObjectMergeRequirement>[];
    final blockers = prepared?.preview.relationBlockers ??
        const <ObjectMergeRelationBlocker>[];

    return AlertDialog(
      key: const ValueKey('object-merge-review-dialog'),
      title: const Text('重複Objectを統合'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('残すObjectを選択してください。統合は自動では実行されません。'),
              const SizedBox(height: 12),
              RadioListTile<bool>(
                key: const ValueKey('object-merge-survivor-current'),
                value: true,
                groupValue: _currentSurvives,
                onChanged: _loading || _finalizing
                    ? null
                    : (value) {
                        if (value != null) _selectSurvivor(value);
                      },
                title: Text(widget.currentTitle),
                subtitle: Text('現在のObject #${widget.currentObjectId} を残す'),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<bool>(
                key: const ValueKey('object-merge-survivor-candidate'),
                value: false,
                groupValue: _currentSurvives,
                onChanged: _loading || _finalizing
                    ? null
                    : (value) {
                        if (value != null) _selectSurvivor(value);
                      },
                title: Text(widget.candidateTitle),
                subtitle: Text('候補Object #${widget.candidateObjectId} を残す'),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 24),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (prepared == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorText != null)
                      Text(
                        _errorText!,
                        key: const ValueKey('object-merge-review-error'),
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const ValueKey('object-merge-review-retry'),
                      onPressed: _prepare,
                      icon: const Icon(Icons.refresh),
                      label: const Text('再試行'),
                    ),
                  ],
                )
              else ...[
                if (requirements.isEmpty)
                  const Text('Object本体の競合はありません。')
                else ...[
                  Text(
                    '競合する内容',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final requirement in requirements)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<ObjectMergeDecision>(
                        key: ValueKey(
                          'object-merge-decision-${requirement.key}',
                        ),
                        initialValue: _decisions[requirement.key],
                        decoration: InputDecoration(
                          labelText: _requirementLabel(requirement),
                          helperText: _requirementHelper(requirement, prepared),
                        ),
                        items: _orderedDecisions(requirement)
                            .map(
                              (decision) => DropdownMenuItem(
                                value: decision,
                                child: Text(_decisionLabel(decision)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _finalizing
                            ? null
                            : (decision) {
                                if (decision == null) return;
                                setState(() {
                                  _decisions = <String, ObjectMergeDecision>{
                                    ..._decisions,
                                    requirement.key: decision,
                                  };
                                });
                              },
                      ),
                    ),
                ],
                if (blockers.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Relationの競合',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  for (final blocker in blockers)
                    ListTile(
                      key: ValueKey('object-merge-blocker-${blocker.key}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.block_outlined),
                      title: Text(blocker.reason),
                      subtitle: Text(blocker.key),
                    ),
                  const Text('Relationの競合が解消されるまで統合できません。'),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorText!,
                    key: const ValueKey('object-merge-review-error'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('object-merge-review-cancel'),
          onPressed: _finalizing ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const ValueKey('object-merge-review-submit'),
          autofocus: false,
          onPressed: !_loading &&
                  !_finalizing &&
                  prepared != null &&
                  plan?.isExecutable == true
              ? _finalize
              : null,
          child: _finalizing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('統合を確認'),
        ),
      ],
    );
  }

  String _requirementLabel(ObjectMergeRequirement requirement) =>
      switch (requirement.kind) {
        ObjectMergeStateKind.title => 'タイトル',
        ObjectMergeStateKind.body => 'Body',
        ObjectMergeStateKind.aliases => '別名',
        ObjectMergeStateKind.property => _propertyLabel(requirement.key),
        ObjectMergeStateKind.lifecycle => 'ライフサイクル',
      };

  String _propertyLabel(String key) {
    final id = int.tryParse(key.substring('property:'.length));
    return id == null ? 'プロパティ' : widget.propertyNames[id] ?? 'プロパティ #$id';
  }

  String _requirementHelper(
    ObjectMergeRequirement requirement,
    ObjectMergePreparedState prepared,
  ) {
    if (requirement.kind == ObjectMergeStateKind.aliases) {
      final survivor = prepared.survivor.aliases.join('、');
      final retired = prepared.retired.aliases.join('、');
      return '残す側: ${survivor.isEmpty ? 'なし' : survivor} / 統合される側: ${retired.isEmpty ? 'なし' : retired}';
    }
    if (requirement.kind == ObjectMergeStateKind.title) {
      return '残す側: ${prepared.survivor.title} / 統合される側: ${prepared.retired.title}';
    }
    return 'どちらの内容を残すか選択してください。';
  }

  List<ObjectMergeDecision> _orderedDecisions(
    ObjectMergeRequirement requirement,
  ) => <ObjectMergeDecision>[
    ObjectMergeDecision.keepSurvivor,
    ObjectMergeDecision.takeRetired,
    ObjectMergeDecision.combine,
  ].where(requirement.allowedDecisions.contains).toList(growable: false);

  String _decisionLabel(ObjectMergeDecision decision) => switch (decision) {
        ObjectMergeDecision.keepSurvivor => '残す側「$_survivorTitle」を採用',
        ObjectMergeDecision.takeRetired => '統合される側「$_retiredTitle」を採用',
        ObjectMergeDecision.combine => '両方を結合',
      };
}
