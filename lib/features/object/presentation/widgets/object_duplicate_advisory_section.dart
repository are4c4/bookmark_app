import 'package:flutter/material.dart';

import '../../../../domain/object_duplicate_candidate.dart';

class ObjectDuplicateAdvisorySection extends StatelessWidget {
  const ObjectDuplicateAdvisorySection({
    super.key,
    required this.candidates,
    required this.failed,
    required this.onOpenCandidate,
    this.onMergeCandidate,
    this.onRetry,
  });

  final List<ObjectDuplicateCandidate> candidates;
  final bool failed;
  final ValueChanged<int> onOpenCandidate;
  final ValueChanged<ObjectDuplicateCandidate>? onMergeCandidate;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!failed && candidates.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('object-duplicate-advisory'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: failed
          ? Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('重複候補を確認できませんでした。')),
                TextButton(
                  key: const ValueKey('object-duplicate-advisory-retry'),
                  onPressed: onRetry,
                  child: const Text('再試行'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.content_copy_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '重複の可能性',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '同じタイトルまたは別名を持つObjectがあります。内容を確認してから扱いを決めてください。',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                for (final candidate in candidates)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      key: ValueKey(
                        'object-duplicate-candidate-${candidate.objectId}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(candidate.canonicalTitle),
                      subtitle: Text(_reason(candidate)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onMergeCandidate != null)
                            TextButton(
                              key: ValueKey(
                                'object-duplicate-merge-${candidate.objectId}',
                              ),
                              onPressed: () => onMergeCandidate!(candidate),
                              child: const Text('統合…'),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => onOpenCandidate(candidate.objectId),
                    ),
                  ),
              ],
            ),
    );
  }
}

String _reason(ObjectDuplicateCandidate candidate) {
  final first = candidate.matches.first;
  final label = switch ((first.proposedKind, first.existingKind)) {
    (
      ObjectDuplicateIdentityKind.canonicalTitle,
      ObjectDuplicateIdentityKind.canonicalTitle,
    ) =>
      '同じタイトル「${first.existingValue}」',
    _ => 'タイトル/別名「${first.existingValue}」が一致',
  };
  final remaining = candidate.matches.length - 1;
  return remaining > 0 ? '$label（ほか$remaining件）' : label;
}
