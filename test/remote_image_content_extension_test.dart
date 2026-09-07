import 'dart:io';

import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/remote_image_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

void main() {
  test('remote Image keeps provenance name but managed extension follows MIME',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'remote_content_extension_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final bytes = img.encodePng(img.Image(width: 3, height: 2));
    final service = RemoteImageStorageService(
      client: MockClient(
        (_) async => http.Response.bytes(
          bytes,
          200,
          headers: const <String, String>{'content-type': 'image/png'},
        ),
      ),
      storage: PhotoStorageService(photoDirectoryPath: directory.path),
    );

    final managed = await service.download(
      'https://cdn.example.com/cover.jpg',
    );

    expect(managed, isNotNull);
    expect(managed!.originalName, 'cover.jpg');
    expect(managed.contentType, 'image/png');
    expect(managed.path.toLowerCase(), endsWith('.png'));
    expect(await File(managed.path).exists(), isTrue);
    expect(img.decodeImage(await File(managed.path).readAsBytes())?.width, 3);
  });
}
