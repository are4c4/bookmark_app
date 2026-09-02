import '../domain/object_type_defaults.dart';
import 'object_type_defaults_store.dart';

/// Resolves persisted ObjectType defaults against app fallback values.
///
/// Database/View layers may still override the returned values afterwards,
/// preserving the full precedence View > Database > ObjectType > app.
class ObjectTypeDefaultsService {
  ObjectTypeDefaultsService({
    required this.store,
    this.resolver = const ObjectTypeDefaultsResolver(),
  });

  final ObjectTypeDefaultsStore store;
  final ObjectTypeDefaultsResolver resolver;

  Future<ResolvedObjectTypeDefaults> resolve({
    required int objectTypeId,
    required ObjectTypeDefaults appFallback,
  }) async {
    final persisted = await store.read(objectTypeId);
    return resolver.resolve(
      appFallback: appFallback,
      objectTypeDefaults: persisted,
    );
  }
}
