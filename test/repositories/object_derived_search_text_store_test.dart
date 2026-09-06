import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_derived_search_text_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late ObjectDerivedSearchTextStore derivedText;
  late int objectTypeId;
  late int objectId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    derivedText = ObjectDerivedSearchTextStore(genericStore);
    objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'File',
    );
    objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Research paper.pdf',
    );
  });

  test('replaces one source without accumulating stale derived tokens', () async {
    await derivedText.replace(
      objectId: objectId,
      sourceKey: 'pdf-text',
      text: 'LegacyExtractedToken',
    );
    expect(await derivedText.readCombined(objectId), 'LegacyExtractedToken');

    await derivedText.replace(
      objectId: objectId,
      sourceKey: 'pdf-text',
      text: 'CurrentExtractedToken',
    );
    final current = await derivedText.readCombined(objectId);
    expect(current, 'CurrentExtractedToken');
    expect(current, isNot(contains('LegacyExtractedToken')));
  });

  test('keeps independent sources deterministic and source-local', () async {
    await derivedText.replace(
      objectId: objectId,
      sourceKey: 'z-ocr',
      text: 'OCR contribution',
    );
    await derivedText.replace(
      objectId: objectId,
      sourceKey: 'a-pdf-text',
      text: 'PDF contribution',
    );

    expect(
      await derivedText.readCombined(objectId),
      'PDF contribution\nOCR contribution',
    );

    await derivedText.clearSource(objectId: objectId, sourceKey: 'z-ocr');
    expect(await derivedText.readCombined(objectId), 'PDF contribution');
  });

  test('blank replacement removes the source contribution', () async {
    await derivedText.replace(
      objectId: objectId,
      sourceKey: 'pdf-text',
      text: 'Disposable extracted text',
    );
    await derivedText.replace(
      objectId: objectId,
      sourceKey: 'pdf-text',
      text: '   ',
    );

    expect(await derivedText.readCombined(objectId), isEmpty);
  });

  test('rejects blank source keys and missing Objects', () async {
    await expectLater(
      derivedText.replace(
        objectId: objectId,
        sourceKey: '   ',
        text: 'text',
      ),
      throwsArgumentError,
    );
    await expectLater(
      derivedText.replace(
        objectId: 999999,
        sourceKey: 'pdf-text',
        text: 'text',
      ),
      throwsArgumentError,
    );
  });

  test('derived text is removed with the canonical Object', () async {
    await derivedText.replace(
      objectId: objectId,
      sourceKey: 'pdf-text',
      text: 'CascadeToken',
    );

    await objectStore.deleteObject(objectId);

    expect(await derivedText.readCombined(objectId), isEmpty);
  });
}
