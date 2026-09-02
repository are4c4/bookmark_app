import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_body_block_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = ObjectBodyBlockFactory();
  const presenter = ObjectBodyBlockPresenter();

  test('presents editable text-like block kinds with metadata', () {
    final heading = presenter.present(
      factory.heading(id: 'h', level: 2, text: 'Heading'),
    );
    final checklist = presenter.present(
      factory.checklist(id: 'c', text: 'Task', checked: true),
    );
    final code = presenter.present(
      factory.code(id: 'code', text: 'x', language: 'dart'),
    );

    expect(heading.kind, ObjectBodyBlockPresentationKind.heading);
    expect(heading.headingLevel, 2);
    expect(heading.isEditableText, isTrue);
    expect(checklist.checked, isTrue);
    expect(code.language, 'dart');
    expect(code.isEditableText, isTrue);
  });

  test('presents references/assets as non-text surfaces', () {
    final object = presenter.present(
      factory.objectReference(id: 'o', objectId: 42),
    );
    final database = presenter.present(
      factory.databaseView(id: 'd', databaseId: 5, viewId: 6),
    );
    final image = presenter.present(
      factory.asset(
        id: 'i',
        type: ObjectBodyBlockType.image,
        assetId: 7,
      ),
    );

    expect(object.kind, ObjectBodyBlockPresentationKind.objectReference);
    expect(database.kind, ObjectBodyBlockPresentationKind.databaseView);
    expect(image.kind, ObjectBodyBlockPresentationKind.asset);
    expect(object.isEditableText, isFalse);
  });

  test('unknown future blocks remain opaque presentation entries', () {
    const future = ObjectBodyBlock(
      id: 'future',
      type: 'futureWidget',
      text: 'keep',
      attributes: <String, dynamic>{'schema': 9},
    );

    final presented = presenter.present(future);
    expect(presented.kind, ObjectBodyBlockPresentationKind.unknown);
    expect(presented.block.toJson(), future.toJson());
    expect(presented.isEditableText, isFalse);
  });

  test('document presentation preserves persisted ordering', () {
    final document = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        factory.paragraph(id: 'p', text: 'one'),
        factory.divider(id: 'd'),
        factory.checklist(id: 'c', text: 'two'),
      ],
    );

    final result = presenter.presentDocument(document);
    expect(result.map((item) => item.block.id), ['p', 'd', 'c']);
  });
}
