import 'object_detail_content.dart';
import 'object_type_defaults.dart';

/// Fully resolved Object-owned state needed by any detail presentation.
///
/// View/Database presentation overrides may wrap this session later, but the
/// underlying Object content and ObjectType defaults remain shared.
class ObjectDetailSession {
  const ObjectDetailSession({
    required this.content,
    required this.defaults,
  });

  final ObjectDetailContent content;
  final ResolvedObjectTypeDefaults defaults;
}
