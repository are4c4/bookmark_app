import 'dart:io';

import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/remote_image_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('downloads image bytes into the app-managed photo directory', () async {
    final directory = await Directory.systemTemp.createTemp('bookmark_image_test_');
    addTearDown(() => directory.delete(recursive: true));
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://cdn.example.com/preview?id=1');
      expect(request.headers['Accept'], 'image/*');
      return http.Response.bytes(
        <int>[1, 2, 3, 4],
        200,
        headers: const <String, String>{
          'content-type': 'image/jpeg; charset=binary',
        },
      );
    });
    final service = RemoteImageStorageService(
      client: client,
      storage: PhotoStorageService(photoDirectoryPath: directory.path),
    );

    final result = await service.download(
      'https://cdn.example.com/preview?id=1',
    );

    expect(result, isNotNull);
    expect(result!.sourceUrl, 'https://cdn.example.com/preview?id=1');
    expect(result.contentType, 'image/jpeg');
    expect(result.originalName, 'remote_image.jpg');
    final stored = File(result.path);
    expect(await stored.exists(), isTrue);
    expect(await stored.readAsBytes(), <int>[1, 2, 3, 4]);
    expect(stored.parent.path, directory.path);
  });

  test('keeps supported remote filename and returns null for non-images',
      () async {
    final directory = await Directory.systemTemp.createTemp('bookmark_image_test_');
    addTearDown(() => directory.delete(recursive: true));
    var nonImage = false;
    final client = MockClient((request) async {
      if (nonImage) {
        return http.Response(
          '<html></html>',
          200,
          headers: const <String, String>{'content-type': 'text/html'},
        );
      }
      return http.Response.bytes(
        <int>[9, 8, 7],
        200,
        headers: const <String, String>{'content-type': 'image/png'},
      );
    });
    final service = RemoteImageStorageService(
      client: client,
      storage: PhotoStorageService(photoDirectoryPath: directory.path),
    );

    final image = await service.download(
      'https://cdn.example.com/path/cover.png?token=x',
    );
    expect(image?.originalName, 'cover.png');
    expect(image?.contentType, 'image/png');

    nonImage = true;
    expect(
      await service.download('https://example.com/not-image'),
      isNull,
    );
  });

  test('HTTP failures are optional while invalid caller URLs fail fast', () async {
    final directory = await Directory.systemTemp.createTemp('bookmark_image_test_');
    addTearDown(() => directory.delete(recursive: true));
    final service = RemoteImageStorageService(
      client: MockClient((_) async => http.Response('missing', 404)),
      storage: PhotoStorageService(photoDirectoryPath: directory.path),
    );

    expect(
      await service.download('https://example.com/missing.jpg'),
      isNull,
    );
    await expectLater(
      service.download('not an absolute URL'),
      throwsArgumentError,
    );
  });

  test('PhotoStorageService rejects empty bytes and unsupported names', () async {
    final directory = await Directory.systemTemp.createTemp('bookmark_image_test_');
    addTearDown(() => directory.delete(recursive: true));
    final storage = PhotoStorageService(photoDirectoryPath: directory.path);

    await expectLater(
      storage.importBytes(bytes: const <int>[], originalName: 'empty.jpg'),
      throwsArgumentError,
    );
    await expectLater(
      storage.importBytes(bytes: const <int>[1], originalName: 'image.svg'),
      throwsArgumentError,
    );
  });
}
