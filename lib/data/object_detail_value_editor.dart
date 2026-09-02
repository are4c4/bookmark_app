import '../domain/object_detail_content.dart';
import '../domain/object_model.dart';
import 'object_detail_edit_service.dart';

enum ObjectDetailValueEditorKind {
  text,
  number,
  checkbox,
  select,
  multiSelect,
  date,
  rating,
  unsupported,
}

class ObjectDetailValueEditorDescriptor {
  const ObjectDetailValueEditorDescriptor({
    required this.kind,
    this.options = const <String>[],
  });

  final ObjectDetailValueEditorKind kind;
  final List<String> options;

  bool get isEditable => kind != ObjectDetailValueEditorKind.unsupported;
}

/// Object-owned description/dispatch layer for Value editors shared by
/// full-page, side-peek and center-peek Object detail surfaces.
///
/// Relation and Computed Properties deliberately resolve to [unsupported].
/// This keeps those mutations on their canonical Relation/Computed paths.
class ObjectDetailValueEditor {
  const ObjectDetailValueEditor(this.editService);

  final ObjectDetailEditService editService;

  ObjectDetailValueEditorDescriptor describe(ObjectPropertyDefinition property) {
    if (!property.isValue) {
      return const ObjectDetailValueEditorDescriptor(
        kind: ObjectDetailValueEditorKind.unsupported,
      );
    }

    switch (property.type) {
      case ObjectPropertyType.text:
      case ObjectPropertyType.url:
        return const ObjectDetailValueEditorDescriptor(
          kind: ObjectDetailValueEditorKind.text,
        );
      case ObjectPropertyType.number:
        return const ObjectDetailValueEditorDescriptor(
          kind: ObjectDetailValueEditorKind.number,
        );
      case ObjectPropertyType.checkbox:
        return const ObjectDetailValueEditorDescriptor(
          kind: ObjectDetailValueEditorKind.checkbox,
        );
      case ObjectPropertyType.select:
        return ObjectDetailValueEditorDescriptor(
          kind: ObjectDetailValueEditorKind.select,
          options: _options(property),
        );
      case ObjectPropertyType.multiSelect:
        return ObjectDetailValueEditorDescriptor(
          kind: ObjectDetailValueEditorKind.multiSelect,
          options: _options(property),
        );
      case ObjectPropertyType.date:
        return const ObjectDetailValueEditorDescriptor(
          kind: ObjectDetailValueEditorKind.date,
        );
      case ObjectPropertyType.rating:
        return const ObjectDetailValueEditorDescriptor(
          kind: ObjectDetailValueEditorKind.rating,
        );
      case ObjectPropertyType.objectRelation:
      case ObjectPropertyType.formula:
      case ObjectPropertyType.rollup:
        return const ObjectDetailValueEditorDescriptor(
          kind: ObjectDetailValueEditorKind.unsupported,
        );
    }
  }

  Future<ObjectDetailContent> submit({
    required ObjectDetailContent content,
    required ObjectPropertyDefinition property,
    required dynamic value,
  }) {
    final descriptor = describe(property);
    switch (descriptor.kind) {
      case ObjectDetailValueEditorKind.text:
      case ObjectDetailValueEditorKind.number:
        return editService.setValue(
          content: content,
          property: property,
          value: value,
        );
      case ObjectDetailValueEditorKind.checkbox:
        if (value is! bool) {
          throw ArgumentError.value(value, 'value', 'Checkbox Value must be bool.');
        }
        return editService.setCheckbox(
          content: content,
          property: property,
          value: value,
        );
      case ObjectDetailValueEditorKind.select:
        if (value != null && value is! String) {
          throw ArgumentError.value(value, 'value', 'Select Value must be String.');
        }
        final selected = value as String?;
        if (selected != null &&
            descriptor.options.isNotEmpty &&
            !descriptor.options.contains(selected)) {
          throw ArgumentError.value(
            value,
            'value',
            'Select Value must be one of the configured options.',
          );
        }
        return editService.setSelect(
          content: content,
          property: property,
          value: selected,
        );
      case ObjectDetailValueEditorKind.multiSelect:
        if (value is! List<String>) {
          throw ArgumentError.value(
            value,
            'value',
            'Multi-select Value must be List<String>.',
          );
        }
        if (descriptor.options.isNotEmpty &&
            value.any((item) => !descriptor.options.contains(item))) {
          throw ArgumentError.value(
            value,
            'value',
            'Multi-select Values must be configured options.',
          );
        }
        return editService.setMultiSelect(
          content: content,
          property: property,
          values: value,
        );
      case ObjectDetailValueEditorKind.date:
        if (value != null && value is! String) {
          throw ArgumentError.value(value, 'value', 'Date Value must be String.');
        }
        return editService.setDate(
          content: content,
          property: property,
          value: value as String?,
        );
      case ObjectDetailValueEditorKind.rating:
        if (value != null && value is! int) {
          throw ArgumentError.value(value, 'value', 'Rating Value must be int.');
        }
        return editService.setRating(
          content: content,
          property: property,
          value: value as int?,
        );
      case ObjectDetailValueEditorKind.unsupported:
        throw ArgumentError.value(
          property.type,
          'property',
          'Relation and Computed Properties are not edited as Values.',
        );
    }
  }

  List<String> _options(ObjectPropertyDefinition property) {
    final raw = property.config['options'];
    if (raw is! List) return const <String>[];
    return List<String>.unmodifiable(raw.whereType<String>());
  }
}
