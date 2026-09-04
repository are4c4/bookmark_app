import 'dart:io';

import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:bookmark_app/services/remote_image_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

void main() {
  test('managed remote image records dimensions once during ingestion', () async {
    final directory = await Directory.systemTemp.createTemp('remote_dimensions_');
    addTearDown(() => directory.delete(recursive: true));
    final bytes = img.encodePng(img.Image(width: 40, height: 80));
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

    final managed = await service.download('https://cdn.example.com/portrait.png');

    expect(managed, isNotNull);
    expect(managed!.pixelWidth, 40);
    expect(managed.pixelHeight, 80);
    expect(managed.aspectRatio, .5);
  });

  test('dimension probing stays optional for undecodable image bytes', () async {
    final directory = await Directory.systemTemp.createTemp('remote_dimensions_');
    addTearDown(() => directory.delete(recursive: true));
    final service = RemoteImageStorageService(
      client: MockClient(
        (_) async => http.Response.bytes(
          const <int>[1, 2, 3, 4],
          200,
          headers: const <String, String>{'content-type': 'image/jpeg'},
        ),
      ),
      storage: PhotoStorageService(photoDirectoryPath: directory.path),
    );

    final managed = await service.download('https://cdn.example.com/legacy.jpg');

    expect(managed, isNotNull);
    expect(managed!.pixelWidth, isNull);
    expect(managed.pixelHeight, isNull);
    expect(managed.aspectRatio, isNull);
    expect(await File(managed.path).exists(), isTrue);
  });
}
