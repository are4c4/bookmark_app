sealed class AppDragPayload {
  const AppDragPayload();
}

class BookmarkDragPayload extends AppDragPayload {
  const BookmarkDragPayload(this.bookmarkIds);
  final Set<int> bookmarkIds;
}

class PhotoDragPayload extends AppDragPayload {
  const PhotoDragPayload(this.photoIds);
  final Set<int> photoIds;
}

class ExternalFilesDragPayload extends AppDragPayload {
  const ExternalFilesDragPayload(this.paths);
  final List<String> paths;
}

sealed class AppDropTarget {
  const AppDropTarget();
}

class WorkspaceDropTarget extends AppDropTarget {
  const WorkspaceDropTarget(this.workspaceId);
  final int workspaceId;
}

class TagDropTarget extends AppDropTarget {
  const TagDropTarget(this.tagId);
  final int tagId;
}

class CollectionDropTarget extends AppDropTarget {
  const CollectionDropTarget(this.collectionId);
  final int collectionId;
}

class PersonRoleDropTarget extends AppDropTarget {
  const PersonRoleDropTarget(this.personId, this.role);
  final int personId;
  final String role;
}

class BookmarkPhotoDropTarget extends AppDropTarget {
  const BookmarkPhotoDropTarget(this.bookmarkId, {this.asCover = false});
  final int bookmarkId;
  final bool asCover;
}
