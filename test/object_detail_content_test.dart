import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_detail_content.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared detail content resolves stored and computed values consistently', () {
    final stored = ObjectPropertyDefinition(
      id: 1,
      objectTypeId: 10,
      name: 'URL',
      type: ObjectPropertyType.url,
      sortOrder: 0,
    );
    final computed = ObjectPropertyDefinition(
      id: 2,
      objectTypeId: 10,
      name: 'Score',
      type: ObjectPropertyType.formula,
      sortOrder: 1,
    );
    final type = AppObjectType(
      id: 10,
      workspaceId: 1,
      name: 'Weblink',
      icon: '🔗',
      kind: ObjectTypeKind.custom,
      sortOrder: 0,
      properties: <ObjectPropertyDefinition>[stored, computed],
    );
    final object = AppObject(
      id: 100,
      objectTypeId: 10,
      title: 'Example',
      createdAt: DateTime(2026, 9, 2),
      updatedAt: DateTime(2026, 9, 2),
      values: const <int, dynamic>{1: 'https://example.com'},
    );
    final content = ObjectDetailContent(
      object: object,
      objectType: type,
      body: ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock.paragraph(id: 'p1', text: 'Notes'),
        ],
      ),
      computedValues: const <int, dynamic>{2: 42},
    );

    expect(content.valueFor(stored), 'https://example.com');
    expect(content.valueFor(computed), 42);
    expect(content.body.blocks.single.text, 'Notes');
    expect(content.object.id, 100);
  });
}
