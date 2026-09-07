import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/canonical_weblink_action_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late SystemObjectStore systemObjects;
  late WeblinkObjectService weblinks;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
  });

  tearDown(() => database.close());

  test('canonical Weblink open and copy use the stored normalized URL', () async {
    final input = 'HTTPS://Example.COM:443/a/../article?q=1#part';
    final object = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: input,
    );
    final definition = await weblinks.ensureDefinition(workspaceId);
    final expected = weblinks.normalizeUrl(input);
    Uri? opened;
    String? copied;
    final actions = CanonicalWeblinkActionService(
      resources: CanonicalWeblinkResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
      ),
      openUrl: (uri) async {
        opened = uri;
        return true;
      },
      copyUrl: (url) async {
        copied = url;
        return true;
      },
    );

    await actions.open(
      weblinkObjectTypeId: definition.objectType.id,
      weblinkObjectId: object.id,
    );
    await actions.copy(
      weblinkObjectTypeId: definition.objectType.id,
      weblinkObjectId: object.id,
    );

    expect(opened, Uri.parse(expected));
    expect(copied, expected);
  });

  test('URL-shaped custom ObjectType does not inherit Weblink native actions',
      () async {
    final customTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'External resource',
    );
    await objectStore.createProperty(
      objectTypeId: customTypeId,
      name: 'URL',
      type: ObjectPropertyType.url,
    );
    final customType = (await objectStore.getObjectType(customTypeId))!;
    final urlProperty = customType.properties.single;
    final objectId = await objectStore.createObject(
      objectTypeId: customTypeId,
      title: 'Custom',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: urlProperty,
      value: 'https://example.test/private',
    );
    var actionCalls = 0;
    final actions = CanonicalWeblinkActionService(
      resources: CanonicalWeblinkResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
      ),
      openUrl: (_) async {
        actionCalls += 1;
        return true;
      },
      copyUrl: (_) async {
        actionCalls += 1;
        return true;
      },
    );

    await expectLater(
      actions.open(
        weblinkObjectTypeId: customTypeId,
        weblinkObjectId: objectId,
      ),
      throwsA(isA<CanonicalWeblinkUnavailableException>()),
    );
    await expectLater(
      actions.copy(
        weblinkObjectTypeId: customTypeId,
        weblinkObjectId: objectId,
      ),
      throwsA(isA<CanonicalWeblinkUnavailableException>()),
    );
    expect(actionCalls, 0);
  });

  test('non-web historical URL data fails closed before native actions', () async {
    final object = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.test/article',
    );
    final definition = await weblinks.ensureDefinition(workspaceId);
    await objectStore.setPropertyValue(
      objectId: object.id,
      property: definition.urlProperty,
      value: 'mailto:reader@example.test',
    );
    var actionCalls = 0;
    final actions = CanonicalWeblinkActionService(
      resources: CanonicalWeblinkResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
      ),
      openUrl: (_) async {
        actionCalls += 1;
        return true;
      },
      copyUrl: (_) async {
        actionCalls += 1;
        return true;
      },
    );

    await expectLater(
      actions.open(
        weblinkObjectTypeId: definition.objectType.id,
        weblinkObjectId: object.id,
      ),
      throwsA(isA<CanonicalWeblinkUnavailableException>()),
    );
    await expectLater(
      actions.copy(
        weblinkObjectTypeId: definition.objectType.id,
        weblinkObjectId: object.id,
      ),
      throwsA(isA<CanonicalWeblinkUnavailableException>()),
    );
    expect(actionCalls, 0);
  });

  test('native action failures do not expose the user URL', () async {
    const secretUrl = 'https://example.test/private/path?token=secret';
    final object = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: secretUrl,
    );
    final definition = await weblinks.ensureDefinition(workspaceId);
    final actions = CanonicalWeblinkActionService(
      resources: CanonicalWeblinkResourceResolver(
        objectStore: objectStore,
        systemObjects: systemObjects,
      ),
      openUrl: (_) async => false,
      copyUrl: (_) async => false,
    );

    Object? openError;
    try {
      await actions.open(
        weblinkObjectTypeId: definition.objectType.id,
        weblinkObjectId: object.id,
      );
    } catch (error) {
      openError = error;
    }
    Object? copyError;
    try {
      await actions.copy(
        weblinkObjectTypeId: definition.objectType.id,
        weblinkObjectId: object.id,
      );
    } catch (error) {
      copyError = error;
    }

    expect(openError, isA<CanonicalWeblinkActionException>());
    expect(copyError, isA<CanonicalWeblinkActionException>());
    expect('$openError', isNot(contains(secretUrl)));
    expect('$copyError', isNot(contains(secretUrl)));
    expect('$openError', isNot(contains('token=secret')));
    expect('$copyError', isNot(contains('token=secret')));
  });
}
