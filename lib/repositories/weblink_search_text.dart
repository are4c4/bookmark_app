import '../data/weblink_object_service.dart';
import '../domain/object_model.dart';
import 'object_property_search_text.dart';

/// Builds the dedicated Weblink metadata contribution for canonical Object
/// search.
///
/// Only user-meaningful resource metadata is emitted. Favicon/preview-image
/// URLs and other media identity values stay out of free-text search.
String buildWeblinkSearchText({
  required AppObject object,
  required WeblinkObjectDefinition definition,
}) {
  final properties = <ObjectPropertyDefinition>[
    definition.urlProperty,
    definition.domainProperty,
    definition.pageTitleProperty,
    definition.siteNameProperty,
    definition.descriptionProperty,
  ];

  return properties
      .map(
        (property) => buildObjectPropertySearchText(
          property: property,
          value: object.values[property.id],
        ),
      )
      .where((text) => text.isNotEmpty)
      .join('\n');
}
