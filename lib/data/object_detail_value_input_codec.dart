import 'object_detail_value_editor.dart';

/// Converts simple text-oriented UI input into the typed values expected by
/// [ObjectDetailValueEditor].
///
/// Presentation surfaces stay responsible for choosing controls (for example a
/// checkbox or picker), while text fields shared by full-page/side/center
/// detail can use one normalization/validation contract.
class ObjectDetailValueInputCodec {
  const ObjectDetailValueInputCodec();

  dynamic decodeText({
    required ObjectDetailValueEditorDescriptor descriptor,
    required String input,
  }) {
    final trimmed = input.trim();
    switch (descriptor.kind) {
      case ObjectDetailValueEditorKind.text:
        return input;
      case ObjectDetailValueEditorKind.number:
        if (trimmed.isEmpty) return null;
        final value = num.tryParse(trimmed);
        if (value == null) {
          throw ArgumentError.value(input, 'input', 'Number Value must be numeric.');
        }
        return value;
      case ObjectDetailValueEditorKind.select:
        if (trimmed.isEmpty) return null;
        _validateOption(descriptor, trimmed);
        return trimmed;
      case ObjectDetailValueEditorKind.multiSelect:
        if (trimmed.isEmpty) return const <String>[];
        final values = input
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
        for (final value in values) {
          _validateOption(descriptor, value);
        }
        return values;
      case ObjectDetailValueEditorKind.date:
        if (trimmed.isEmpty) return null;
        if (DateTime.tryParse(trimmed) == null) {
          throw ArgumentError.value(input, 'input', 'Date Value must be parseable.');
        }
        return trimmed;
      case ObjectDetailValueEditorKind.rating:
        if (trimmed.isEmpty) return null;
        final value = int.tryParse(trimmed);
        if (value == null || value < 0 || value > 5) {
          throw RangeError.range(value, 0, 5, 'input', 'Rating Value must be 0-5.');
        }
        return value;
      case ObjectDetailValueEditorKind.checkbox:
        throw ArgumentError.value(
          descriptor.kind,
          'descriptor',
          'Checkbox Value must come from a boolean control.',
        );
      case ObjectDetailValueEditorKind.unsupported:
        throw ArgumentError.value(
          descriptor.kind,
          'descriptor',
          'Unsupported Property has no Value input codec.',
        );
    }
  }

  void _validateOption(
    ObjectDetailValueEditorDescriptor descriptor,
    String value,
  ) {
    if (descriptor.options.isNotEmpty && !descriptor.options.contains(value)) {
      throw ArgumentError.value(
        value,
        'input',
        'Value must be one of the configured options.',
      );
    }
  }
}
