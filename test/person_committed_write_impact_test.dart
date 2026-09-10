import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PersonObjectWriteService service;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    service = PersonObjectWriteService.forDatabase(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('create exposes committed canonical Person identity', () async {
    final impact = await service.createWithImpact(
      workspaceId: workspaceId,
      name: 'Alice',
      note: 'note',
    );

    expect(impact.legacyPersonId, greaterThan(0));
    expect(impact.canonicalObjectId, greaterThan(0));
    expect(impact.canonicalMutationCommitted, isTrue);
  });

  test(
    'update exposes the same canonical Person identity after commit',
    () async {
      final created = await service.createWithImpact(
        workspaceId: workspaceId,
        name: 'Before',
      );

      final updated = await service.updateWithImpact(
        workspaceId: workspaceId,
        personId: created.legacyPersonId,
        name: 'After',
        note: 'changed',
      );

      expect(updated, isNotNull);
      expect(updated!.legacyPersonId, created.legacyPersonId);
      expect(updated.canonicalObjectId, created.canonicalObjectId);
      expect(updated.canonicalMutationCommitted, isTrue);
    },
  );

  test(
    'duplicate create without a canonical write is distinguishable',
    () async {
      final created = await service.createWithImpact(
        workspaceId: workspaceId,
        name: 'Existing',
      );

      final duplicate = await service.createWithImpact(
        workspaceId: workspaceId,
        name: 'Existing',
      );

      expect(duplicate.legacyPersonId, created.legacyPersonId);
      expect(duplicate.canonicalObjectId, created.canonicalObjectId);
      expect(duplicate.canonicalMutationCommitted, isFalse);
    },
  );

  test('failed update exposes no successful impact result', () async {
    final alice = await service.createWithImpact(
      workspaceId: workspaceId,
      name: 'Alice',
    );
    await service.createWithImpact(workspaceId: workspaceId, name: 'Bob');

    await expectLater(
      service.updateWithImpact(
        workspaceId: workspaceId,
        personId: alice.legacyPersonId,
        name: 'Bob',
      ),
      throwsA(anything),
    );
  });
}
