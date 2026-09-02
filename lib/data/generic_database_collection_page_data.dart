import '../domain/object_model.dart';
import 'database_collection_resolver.dart';
import 'generic_database_store.dart';

class GenericDatabaseCollectionPageData {
  const GenericDatabaseCollectionPageData({
    required this.database,
    required this.collection,
    required this.properties,
    required this.records,
  });

  /// Collection container identity used for Database name/icon/View scope.
  final GenericDatabaseDefinitionRecord database;

  /// Resolved target ObjectType and Database-level membership.
  final ResolvedDatabaseCollection collection;

  /// Presentation/editing schema from the collection target ObjectType.
  final List<GenericPropertyRecord> properties;

  /// Legacy GenericRecord presentation rows for the resolved member Objects.
  final List<GenericRecord> records;

  AppObjectType get objectType => collection.objectType;
  List<AppObject> get objects => collection.objects;
}

/// Loads the two identities that `GenericDatabasePage` needs during the
/// ObjectType -> Database collection migration.
///
/// The Database record remains the owner of name/icon/View scope, while
/// Properties/Objects/records come from the configured target ObjectType after
/// Database-level collection filtering. This prevents a collection targeting
/// another ObjectType from accidentally reading the collection container's
/// legacy schema/records.
class GenericDatabaseCollectionPageLoader {
  const GenericDatabaseCollectionPageLoader({
    required this.genericStore,
    required this.collectionResolver,
  });

  final GenericDatabaseStore genericStore;
  final DatabaseCollectionResolver collectionResolver;

  Future<GenericDatabaseCollectionPageData?> load(int databaseId) async {
    final database = await genericStore.getDatabase(databaseId);
    if (database == null) return null;

    final collection = await collectionResolver.resolve(databaseId);
    if (collection == null) return null;

    final targetId = collection.objectType.id;
    final properties = await genericStore.listProperties(targetId);
    final targetRecords = await genericStore.listRecords(targetId);
    final recordById = <int, GenericRecord>{
      for (final record in targetRecords) record.id: record,
    };
    final records = collection.objects
        .map((object) => recordById[object.id])
        .whereType<GenericRecord>()
        .toList(growable: false);

    return GenericDatabaseCollectionPageData(
      database: database,
      collection: collection,
      properties: List<GenericPropertyRecord>.unmodifiable(properties),
      records: List<GenericRecord>.unmodifiable(records),
    );
  }
}
