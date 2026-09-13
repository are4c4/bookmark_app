import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_block_edit_service.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same-kind persisted conversion does not attempt a CAS write', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    const current = ObjectBodyDocument(
      blocks: <ObjectBodyBlock>[
        ObjectBodyBlock(
          id: 'heading',
          type: ObjectBodyBlockType.heading,
          text: 'unchanged',
          attributes: <String, dynamic>{ObjectBodyBlockAttribute.level: 3},
        ),
      ],
    );
    final bodyStore = _CountingBodyStore(genericStore, current);
    final service = ObjectBodyBlockEditService(bodyStore: bodyStore);

    final result = await service.convertBlock(
      objectId: 1,
      blockId: 'heading',
      targetType: ObjectBodyBlockType.heading,
      headingLevel: 1,
    );

    expect(identical(result, current), isTrue);
    expect(bodyStore.writeAttempts, 0);
    expect(result.blocks.single.attributes, <String, dynamic>{
      ObjectBodyBlockAttribute.level: 3,
    });
  });
}

class _CountingBodyStore extends ObjectBodyStore {
  _CountingBodyStore(GenericDatabaseStore store, this.current) : super(store);

  final ObjectBodyDocument current;
  int writeAttempts = 0;

  @override
  Future<ObjectBodyDocument> read(int objectId) async => current;

  @override
  Future<bool> writeIfUnchanged({
    required int objectId,
    required ObjectBodyDocument expected,
    required ObjectBodyDocument document,
  }) async {
    writeAttempts += 1;
    return true;
  }
}
