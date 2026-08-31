import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../domain/drag_drop_intent.dart';

class DragDropResult {
  const DragDropResult({required this.changed, required this.message});
  final int changed;
  final String message;
}

class DragDropCoordinator {
  const DragDropCoordinator(this.repository);

  final BookmarkRepository repository;

  Future<DragDropResult> perform(
    AppDragPayload payload,
    AppDropTarget target,
  ) async {
    if (payload is BookmarkDragPayload && target is WorkspaceDropTarget) {
      final workspaces = await repository.listWorkspaces();
      final workspace = workspaces.where((item) => item.id == target.workspaceId).firstOrNull;
      if (workspace == null) return const DragDropResult(changed: 0, message: 'Workspaceが見つかりません');
      await repository.moveBookmarksToWorkspace(payload.bookmarkIds, workspace);
      return DragDropResult(changed: payload.bookmarkIds.length, message: '${workspace.name}へ移動しました');
    }

    if (payload is BookmarkDragPayload && target is TagDropTarget) {
      final tags = await repository.watchTags().first;
      final tag = tags.where((item) => item.id == target.tagId).firstOrNull;
      if (tag == null) return const DragDropResult(changed: 0, message: 'タグが見つかりません');
      final bookmarks = await repository.watchAll().first;
      final byId = {for (final bookmark in bookmarks) bookmark.id: bookmark};
      var changed = 0;
      for (final id in payload.bookmarkIds) {
        final bookmark = byId[id];
        if (bookmark == null) continue;
        final selected = <int, Tag>{for (final item in bookmark.tags) item.id: item};
        selected[tag.id] = tag;
        await repository.setBookmarkTagsFromDatabase(bookmark, selected.values);
        changed += 1;
      }
      return DragDropResult(changed: changed, message: '$changed件に「${tag.name}」を追加しました');
    }

    if (payload is BookmarkDragPayload && target is CollectionDropTarget) {
      final collections = await repository.watchCollections().first;
      final collection = collections.where((item) => item.id == target.collectionId).firstOrNull;
      if (collection == null) return const DragDropResult(changed: 0, message: 'コレクションが見つかりません');
      final bookmarks = await repository.watchAll().first;
      final byId = {for (final bookmark in bookmarks) bookmark.id: bookmark};
      var changed = 0;
      for (final id in payload.bookmarkIds) {
        final bookmark = byId[id];
        if (bookmark == null) continue;
        final selected = <int, CollectionRecord>{for (final item in bookmark.collections) item.id: item};
        selected[collection.id] = collection;
        await repository.setBookmarkCollections(bookmark, selected.values);
        changed += 1;
      }
      return DragDropResult(changed: changed, message: '$changed件を「${collection.name}」へ追加しました');
    }

    if (payload is BookmarkDragPayload && target is PersonRoleDropTarget) {
      final people = await repository.watchPeople().first;
      final person = people.where((item) => item.id == target.personId).firstOrNull;
      if (person == null) return const DragDropResult(changed: 0, message: '人物が見つかりません');
      final bookmarks = await repository.watchAll().first;
      final byId = {for (final bookmark in bookmarks) bookmark.id: bookmark};
      var changed = 0;
      for (final id in payload.bookmarkIds) {
        final bookmark = byId[id];
        if (bookmark == null) continue;
        final assignments = await repository.watchPersonRoles(bookmark).first;
        final current = assignments
            .where((assignment) => assignment.role == target.role)
            .map((assignment) => assignment.person)
            .toList();
        final selected = <int, Person>{for (final item in current) item.id: item};
        selected[person.id] = person;
        await repository.setPeopleForRole(bookmark, target.role, selected.values);
        changed += 1;
      }
      return DragDropResult(changed: changed, message: '$changed件に${target.role}「${person.name}」を追加しました');
    }

    if (payload is PhotoDragPayload && target is BookmarkPhotoDropTarget) {
      final photos = await repository.watchPhotos().first;
      final bookmarks = await repository.watchAll().first;
      final bookmark = bookmarks.where((item) => item.id == target.bookmarkId).firstOrNull;
      if (bookmark == null) return const DragDropResult(changed: 0, message: 'ブックマークが見つかりません');
      final selectedPhotos = photos.where((photo) => payload.photoIds.contains(photo.id)).toList();
      if (selectedPhotos.isEmpty) return const DragDropResult(changed: 0, message: '写真が見つかりません');
      await repository.attachPhotos(
        bookmark,
        selectedPhotos,
        coverPhoto: target.asCover ? selectedPhotos.first : null,
      );
      return DragDropResult(changed: selectedPhotos.length, message: '${selectedPhotos.length}枚の写真を追加しました');
    }

    return const DragDropResult(changed: 0, message: 'このドラッグ＆ドロップ操作にはまだ対応していません');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
