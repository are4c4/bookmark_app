import 'dart:convert';

import 'package:bookmark_app/services/bookmark_metadata_service.dart';
import 'package:bookmark_app/services/weblink_metadata_target_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('WeblinkMetadataTargetPolicy', () {
    test('rejects local, private, link-local, and single-label targets', () {
      final blocked = <String>[
        'http://localhost/secret',
        'http://sub.localhost/secret',
        'http://printer.local/secret',
        'http://intranet/secret',
        'http://127.0.0.1/secret',
        'http://10.0.0.1/secret',
        'http://100.64.0.1/secret',
        'http://169.254.169.254/latest/meta-data',
        'http://172.16.0.1/secret',
        'http://192.168.1.1/secret',
        'http://[::1]/secret',
        'http://[fc00::1]/secret',
        'http://[fe80::1]/secret',
      ];

      for (final raw in blocked) {
        expect(
          WeblinkMetadataTargetPolicy.isAllowed(Uri.parse(raw)),
          isFalse,
          reason: raw,
        );
      }
    });

    test('allows ordinary public DNS and public literal targets', () {
      expect(
        WeblinkMetadataTargetPolicy.isAllowed(
          Uri.parse('https://www.resource.test/article'),
        ),
        isTrue,
      );
      expect(
        WeblinkMetadataTargetPolicy.isAllowed(Uri.parse('https://8.8.8.8/')),
        isTrue,
      );
      expect(
        WeblinkMetadataTargetPolicy.isAllowed(
          Uri.parse('https://[2606:4700:4700::1111]/'),
        ),
        isTrue,
      );
    });
  });

  test('direct private target falls back without issuing a request', () async {
    var requestCount = 0;
    final service = BookmarkMetadataService(
      client: MockClient((request) async {
        requestCount += 1;
        return http.Response('unexpected', 200);
      }),
    );

    final metadata = await service.fetch(
      'http://169.254.169.254/latest/meta-data',
    );

    expect(requestCount, 0);
    expect(metadata.url, 'http://169.254.169.254/latest/meta-data');
    expect(metadata.title, '169.254.169.254');
  });

  test(
    'redirect to a private target is rejected before the second request',
    () async {
      final requested = <Uri>[];
      final service = BookmarkMetadataService(
        client: MockClient((request) async {
          requested.add(request.url);
          if (requested.length == 1) {
            return http.Response(
              '',
              302,
              headers: const {'location': 'http://127.0.0.1/admin'},
            );
          }
          return http.Response('forbidden private response', 200);
        }),
      );

      final metadata = await service.fetch(
        'https://public.resource.test/start',
      );

      expect(requested, [Uri.parse('https://public.resource.test/start')]);
      expect(metadata.url, 'https://public.resource.test/start');
      expect(metadata.title, 'public.resource.test');
    },
  );

  test(
    'public redirects are followed only after each target is validated',
    () async {
      final requested = <Uri>[];
      final service = BookmarkMetadataService(
        client: MockClient((request) async {
          requested.add(request.url);
          if (requested.length == 1) {
            return http.Response(
              '',
              302,
              headers: const {'location': 'https://cdn.resource.test/final/'},
            );
          }
          return http.Response(
            '<html><head><title>Public redirect target</title></head></html>',
            200,
            headers: const {'content-type': 'text/html'},
          );
        }),
      );

      final metadata = await service.fetch(
        'https://public.resource.test/start',
      );

      expect(requested, [
        Uri.parse('https://public.resource.test/start'),
        Uri.parse('https://cdn.resource.test/final/'),
      ]);
      expect(metadata.url, 'https://public.resource.test/start');
      expect(metadata.title, 'Public redirect target');
    },
  );

  test('transport-exposed private final URL fails closed', () async {
    final requestedUrl = Uri.parse('https://public.resource.test/start');
    final service = BookmarkMetadataService(
      client: _FinalUrlClient(
        requestedUrl: requestedUrl,
        finalUrl: Uri.parse('http://192.168.1.10/private'),
      ),
    );

    final metadata = await service.fetch(requestedUrl.toString());

    expect(metadata.url, requestedUrl.toString());
    expect(metadata.title, 'public.resource.test');
  });
}

class _FinalUrlClient extends http.BaseClient {
  _FinalUrlClient({required this.requestedUrl, required this.finalUrl});

  final Uri requestedUrl;
  final Uri finalUrl;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    expect(request.url, requestedUrl);
    expect(request.followRedirects, isFalse);
    return _StreamedResponseWithUrl(
      Stream<List<int>>.value(
        utf8.encode('<html><head><title>private secret</title></head></html>'),
      ),
      200,
      url: finalUrl,
      request: request,
      headers: const {'content-type': 'text/html'},
    );
  }
}

class _StreamedResponseWithUrl extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _StreamedResponseWithUrl(
    super.stream,
    super.statusCode, {
    required this.url,
    super.request,
    super.headers,
  });

  @override
  final Uri url;
}
