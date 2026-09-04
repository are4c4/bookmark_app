import 'package:flutter/material.dart';

import '../../../../data/generic_database_store.dart';
import '../../../../domain/object_detail_property_presentation.dart';
import '../../../../domain/object_model.dart';
import '../../../object/presentation/widgets/object_property_value_view.dart';

/// Thin adapter from the generic Database persistence record to the shared
/// Object Property semantic renderer.
///
/// Relation ids are deliberately never rendered here. Callers must provide
/// canonical, already-resolved Object titles through [relationLabels].
class DatabasePropertyValueView extends StatelessWidget {
  const DatabasePropertyValueView({
    super.key,
    required this.property,
    required this.value,
    this.relationLabels = const <String>[],
    this.density = ObjectPropertyValueDensity.compact,
    this.maxItems,
  });

  final GenericPropertyRecord property;
  final dynamic value;
  final List<String> relationLabels;
  final ObjectPropertyValueDensity density;
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final objectProperty = ObjectPropertyDefinition(
      id: property.id,
      objectTypeId: property.databaseId,
      name: property.name,
      type: _objectPropertyType(property.type),
      sortOrder: property.sortOrder,
      config: property.config,
    );
    final presenter = const ObjectDetailPropertyPresenter();
    final presentation = ObjectDetailPropertyPresentation(
      property: objectProperty,
      value: value,
      displayText: objectProperty.isRelation ? null : presenter.formatValue(value),
      isHidden: false,
    );
    return ObjectPropertyValueView(
      presentation: presentation,
      relationLabels: relationLabels,
      density: density,
      maxItems: maxItems,
    );
  }

  ObjectPropertyType _objectPropertyType(String type) => switch (type) {
        'number' => ObjectPropertyType.number,
        'checkbox' => ObjectPropertyType.checkbox,
        'date' => ObjectPropertyType.date,
        'url' => ObjectPropertyType.url,
        'select' => ObjectPropertyType.select,
        'multiSelect' => ObjectPropertyType.multiSelect,
        'relation' => ObjectPropertyType.objectRelation,
        'image' => ObjectPropertyType.image,
        'file' => ObjectPropertyType.file,
        'rating' => ObjectPropertyType.rating,
        'createdTime' => ObjectPropertyType.createdTime,
        'updatedTime' => ObjectPropertyType.updatedTime,
        'formula' => ObjectPropertyType.formula,
        'rollup' => ObjectPropertyType.rollup,
        _ => ObjectPropertyType.text,
      };
}
