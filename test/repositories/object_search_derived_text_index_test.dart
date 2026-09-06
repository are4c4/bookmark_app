import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_derived_search_text_store.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replaceable derived text participates without stale token accumulation',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final derivedText = ObjectDerivedSearchTextStore(genericStore);
    final search = ObjectSearchRepository(genericStore);

    final fileTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'File',
    );
    final focusedId = await objectStore.createObject(
      objectTypeId: fileTypeId,
      title: 'Research paper',
    );
    final unrelatedId = await objectStore.createObject(
      objectTypeId: fileTypeId,
      title: 'Unrelated file token',
    );

    await derivedText.replace(
      objectId: focusedId,
      sourceKey: 'pdf-text',
      text: 'LegacyExtractedSearchToken',
    );
    await search.rebuildWorkspace(workspaceId);

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'legacyextracted',
      ))
          .map((hit) => hit.objectId),
      contains(focusedId),
    );

    await derivedText.replace(
      objectId: focusedId,
      sourceKey: 'pdf-text',
      text: 'CurrentExtractedSearchToken',
    );
    await derivedText.replace(
      objectId: focusedId,
      sourceKey: 'ocr',
      text: 'IndependentOcrSearchToken',
    );
    await search.refreshObject(focusedId);

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'currentextracted',
      ))
          .map((hit) => hit.objectId),
      contains(focusedId),
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'independentocr',
      ))
          .map((hit) => hit.objectId),
      contains(focusedId),
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'legacyextracted',
      ))
          .map((hit) => hit.objectId),
      isNot(contains(focusedId)),
      reason: 'replacing one derived source must remove stale FTS tokens',
    );

    await derivedText.clearSource(
      objectId: focusedId,
      sourceKey: 'pdf-text',
    );
    await search.refreshObject(focusedId);

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'currentextracted',
      ))
          .map((hit) => hit.objectId),
      isNot(contains(focusedId)),
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'independentocr',
      ))
          .map((hit) => hit.objectId),
      contains(focusedId),
      reason: 'clearing one producer must not erase another producer source',
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'unrelated',
      ))
          .map((hit) => hit.objectId),
      contains(unrelatedId),
      reason: 'focused derived-text refresh must leave unrelated rows intact',
    );
  });
}
