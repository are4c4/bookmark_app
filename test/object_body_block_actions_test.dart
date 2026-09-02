import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_actions.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = ObjectBodyInsertBlockFactory();
  const positions = ObjectBodyBlockPositionResolver();

  test('builds all generic insert kinds with canonical block metadata', () {
    final blocks = <ObjectBodyInsertKind, ObjectBodyBlock>{
      for (final kind in ObjectBodyInsertKind.values)
        kind: factory.build(kind: kind, id: kind.name, text: 'text'),
    };

    expect(blocks[ObjectBodyInsertKind.paragraph]!.type, ObjectBodyBlockType.paragraph);
    expect(blocks[ObjectBodyInsertKind.heading1]!.attributes[ObjectBodyBlockAttribute.level], 1);
    expect(blocks[ObjectBodyInsertKind.heading2]!.attributes[ObjectBodyBlockAttribute.level], 2);
    expect(blocks[ObjectBodyInsertKind.heading3]!.attributes[ObjectBodyBlockAttribute.level], 3);
    expect(blocks[ObjectBodyInsertKind.bulletedListItem]!.type, ObjectBodyBlockType.bulletedListItem);
    expect(blocks[ObjectBodyInsertKind.numberedListItem]!.type, ObjectBodyBlockType.numberedListItem);
    expect(blocks[ObjectBodyInsertKind.checklist]!.attributes[ObjectBodyBlockAttribute.checked], isFalse);
    expect(blocks[ObjectBodyInsertKind.quote]!.type, ObjectBodyBlockType.quote);
    expect(blocks[ObjectBodyInsertKind.callout]!.type, ObjectBodyBlockType.callout);
    expect(blocks[ObjectBodyInsertKind.code]!.type, ObjectBodyBlockType.code);
    expect(blocks[ObjectBodyInsertKind.divider]!.type, ObjectBodyBlockType.divider);
    expect(blocks[ObjectBodyInsertKind.divider]!.text, isNull);
  });

  test('resolves movement boundaries from current document order', () {
    const document = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph),
      ObjectBodyBlock(id: 'b', type: ObjectBodyBlockType.paragraph),
      ObjectBodyBlock(id: 'c', type: ObjectBodyBlockType.paragraph),
    ]);

    final first = positions.resolve(document, 'a');
    final middle = positions.resolve(document, 'b');
    final last = positions.resolve(document, 'c');

    expect(first.canMoveUp, isFalse);
    expect(first.canMoveDown, isTrue);
    expect(middle.canMoveUp, isTrue);
    expect(middle.canMoveDown, isTrue);
    expect(last.canMoveUp, isTrue);
    expect(last.canMoveDown, isFalse);
  });

  test('position resolver fails closed for invalid block identity', () {
    const document = ObjectBodyDocument(blocks: [
      ObjectBodyBlock(id: 'a', type: ObjectBodyBlockType.paragraph),
    ]);
    expect(() => positions.resolve(document, ''), throwsArgumentError);
    expect(() => positions.resolve(document, 'missing'), throwsStateError);
  });
}
