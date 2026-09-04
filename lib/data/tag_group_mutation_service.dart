import 'tag_group_store.dart';

class TagGroupNameConflictException implements Exception {
  const TagGroupNameConflictException();

  @override
  String toString() => '同じ名前のタググループが既にあります';
}

/// Validated mutation boundary for user-facing Tag Group management.
///
/// The database UNIQUE constraint remains the final integrity guard, while
/// routine create/rename flows fail with a concise domain error before raw
/// SQLite diagnostics can leak into the UI.
class TagGroupMutationService {
  const TagGroupMutationService(this.store);

  final TagGroupStore store;

  Future<int> createGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('グループ名が空です');
    await _requireUniqueName(trimmed);
    try {
      return await store.createGroup(trimmed);
    } catch (error) {
      _translateConstraint(error);
      rethrow;
    }
  }

  Future<void> renameGroup(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('グループ名が空です');
    final groups = await store.listGroups();
    if (!groups.any((group) => group.id == id)) {
      throw ArgumentError('グループが存在しません');
    }
    await _requireUniqueName(trimmed, excludingId: id, groups: groups);
    try {
      await store.renameGroup(id, trimmed);
    } catch (error) {
      _translateConstraint(error);
      rethrow;
    }
  }

  Future<void> deleteGroup(int id) => store.deleteGroup(id);

  Future<void> _requireUniqueName(
    String name, {
    int? excludingId,
    List<TagGroupInfo>? groups,
  }) async {
    final current = groups ?? await store.listGroups();
    final normalized = name.toLowerCase();
    final duplicate = current.any(
      (group) =>
          group.id != excludingId && group.name.trim().toLowerCase() == normalized,
    );
    if (duplicate) throw const TagGroupNameConflictException();
  }

  void _translateConstraint(Object error) {
    if ('$error'.contains('UNIQUE constraint failed: tag_groups.name')) {
      throw const TagGroupNameConflictException();
    }
  }
}
