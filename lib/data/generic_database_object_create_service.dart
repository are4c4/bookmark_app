import '../domain/object_group.dart';
import '../domain/object_model.dart';
import 'generic_database_collection_page_data.dart';
import 'object_board_create_service.dart';
import 'object_store.dart';

/// Object creation facade for collection-backed Database pages.
///
/// Database identity and ObjectType identity may differ. This service always
/// resolves the current Database collection first so new Objects are created in
/// the configured target ObjectType instead of assuming `databaseId` is also an
/// ObjectType id.
class GenericDatabaseObjectCreateService {
  const GenericDatabaseObjectCreateService({
    required this.pageLoader,
    required this.objectStore,
    required this.boardCreate,
  });

  final GenericDatabaseCollectionPageLoader pageLoader;
  final ObjectStore objectStore;
  final ObjectBoardCreateService boardCreate;

  Future<int> create({
    required int databaseId,
    required String title,
  }) async {
    final page = await _load(databaseId);
    return objectStore.createObject(
      objectTypeId: page.objectType.id,
      title: title,
    );
  }

  Future<int> createInGroup({
    required int databaseId,
    required String title,
    required ObjectPropertyDefinition groupProperty,
    required ObjectGroupBucket<AppObject> targetGroup,
  }) async {
    final page = await _load(databaseId);
    ObjectPropertyDefinition? canonicalProperty;
    for (final property in page.objectType.properties) {
      if (property.id == groupProperty.id) {
        canonicalProperty = property;
        break;
      }
    }
    if (canonicalProperty == null) {
      throw ArgumentError.value(
        groupProperty.id,
        'groupProperty',
        'Board group Property must belong to the Database collection target ObjectType.',
      );
    }

    return boardCreate.create(
      objectTypeId: page.objectType.id,
      title: title,
      groupProperty: canonicalProperty,
      targetGroup: targetGroup,
    );
  }

  Future<GenericDatabaseCollectionPageData> _load(int databaseId) async {
    final page = await pageLoader.load(databaseId);
    if (page == null) {
      throw ArgumentError.value(
        databaseId,
        'databaseId',
        'Database collection does not exist.',
      );
    }
    return page;
  }
}
