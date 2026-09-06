import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../data/generic_database_store.dart';
import '../repositories/object_global_search_service.dart';
import 'object_global_search_page.dart';

/// Compatibility entrypoint retained for the app shell while global search
/// itself is now canonical Object search.
///
/// Keeping this wrapper avoids coupling the shell to search infrastructure and
/// lets legacy callers continue to pass the root repository during migration.
class GlobalSearchPage extends StatelessWidget {
  const GlobalSearchPage({
    super.key,
    required this.repository,
    this.searchService,
  });

  final BookmarkRepository repository;
  final ObjectGlobalSearchService? searchService;

  @override
  Widget build(BuildContext context) {
    final store = GenericDatabaseStore(repository.workspaceStore.database);
    return ObjectGlobalSearchPage(
      store: store,
      workspaceId: repository.workspaceId,
      searchService: searchService,
    );
  }
}
