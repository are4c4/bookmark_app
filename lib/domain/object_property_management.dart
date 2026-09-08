import 'object_model.dart';

/// Canonical Object Property metadata key for Values whose persisted value is
/// part of an Object-owned identity invariant rather than ordinary user data.
const String objectPropertyIdentityManagedConfigKey = 'identityManaged';

extension ObjectPropertyManagement on ObjectPropertyDefinition {
  /// Whether this Property may only be mutated through its owning identity
  /// service instead of generic Object detail Value editing.
  bool get isIdentityManaged =>
      config[objectPropertyIdentityManagedConfigKey] == true;
}
