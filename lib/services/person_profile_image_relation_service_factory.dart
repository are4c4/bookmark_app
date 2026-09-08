import '../data/bookmark_repository.dart';
import 'person_profile_image_relation_service.dart';

/// Presentation composition boundary for canonical Person profile Images.
PersonProfileImageRelationService createPersonProfileImageRelationService(
  BookmarkRepository repository,
) =>
    PersonProfileImageRelationService(repository.workspaceStore.database);
