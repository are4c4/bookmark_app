import 'package:bookmark_app/data/object_detail_value_input_codec.dart';
import 'package:bookmark_app/data/object_detail_value_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = ObjectDetailValueInputCodec();

  const text = ObjectDetailValueEditorDescriptor(
    kind: ObjectDetailValueEditorKind.text,
  );
  const number = ObjectDetailValueEditorDescriptor(
    kind: ObjectDetailValueEditorKind.number,
  );
  const select = ObjectDetailValueEditorDescriptor(
    kind: ObjectDetailValueEditorKind.select,
    options: ['A', 'B'],
  );
  const multiSelect = ObjectDetailValueEditorDescriptor(
    kind: ObjectDetailValueEditorKind.multiSelect,
    options: ['A', 'B', 'C'],
  );
  const date = ObjectDetailValueEditorDescriptor(
    kind: ObjectDetailValueEditorKind.date,
  );
  const rating = ObjectDetailValueEditorDescriptor(
    kind: ObjectDetailValueEditorKind.rating,
  );

  test('text preserves user whitespace while typed fields normalize it', () {
    expect(codec.decodeText(descriptor: text, input: '  note  '), '  note  ');
    expect(codec.decodeText(descriptor: number, input: ' 12.5 '), 12.5);
    expect(codec.decodeText(descriptor: select, input: ' A '), 'A');
    expect(codec.decodeText(descriptor: date, input: ' 2026-09-03 '), '2026-09-03');
    expect(codec.decodeText(descriptor: rating, input: ' 4 '), 4);
  });

  test('empty typed input maps to clear values', () {
    expect(codec.decodeText(descriptor: number, input: '  '), isNull);
    expect(codec.decodeText(descriptor: select, input: ''), isNull);
    expect(codec.decodeText(descriptor: multiSelect, input: ''), <String>[]);
    expect(codec.decodeText(descriptor: date, input: ''), isNull);
    expect(codec.decodeText(descriptor: rating, input: ''), isNull);
  });

  test('multi-select parses comma-separated configured options', () {
    expect(
      codec.decodeText(descriptor: multiSelect, input: 'A, C'),
      ['A', 'C'],
    );
  });

  test('invalid numeric, option, date and rating input fail before mutation', () {
    expect(
      () => codec.decodeText(descriptor: number, input: 'twelve'),
      throwsArgumentError,
    );
    expect(
      () => codec.decodeText(descriptor: select, input: 'Z'),
      throwsArgumentError,
    );
    expect(
      () => codec.decodeText(descriptor: multiSelect, input: 'A, Z'),
      throwsArgumentError,
    );
    expect(
      () => codec.decodeText(descriptor: date, input: 'not-a-date'),
      throwsArgumentError,
    );
    expect(
      () => codec.decodeText(descriptor: rating, input: '6'),
      throwsRangeError,
    );
  });

  test('checkbox and unsupported values cannot be decoded from text', () {
    const checkbox = ObjectDetailValueEditorDescriptor(
      kind: ObjectDetailValueEditorKind.checkbox,
    );
    const unsupported = ObjectDetailValueEditorDescriptor(
      kind: ObjectDetailValueEditorKind.unsupported,
    );
    expect(
      () => codec.decodeText(descriptor: checkbox, input: 'true'),
      throwsArgumentError,
    );
    expect(
      () => codec.decodeText(descriptor: unsupported, input: 'value'),
      throwsArgumentError,
    );
  });
}
