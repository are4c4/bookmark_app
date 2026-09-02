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

  final GenericDatabaseDefinitionRecord database;
  final ResolvedDatabaseCollection collection;
  final List<GenericPropertyRecord> properties;
  final List<GenericRecord> records;

  AppObjectType get objectType => collection.objectType;
  List<AppObject> get objects => collection.objects;
}

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
