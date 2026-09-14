import 'dart:io';

/// Fail-closed network target policy for Weblink metadata enrichment.
///
/// This policy deliberately applies only to metadata-fetch network targets. It
/// does not redefine canonical Weblink identity or presentation URL validation.
abstract final class WeblinkMetadataTargetPolicy {
  static bool isAllowed(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (!uri.hasAuthority || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }

    var host = uri.host.toLowerCase();
    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.isEmpty) return false;

    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local')) {
      return false;
    }

    final address = InternetAddress.tryParse(host);
    if (address != null) return _isPublicAddress(address);

    // Single-label hostnames are commonly local resolver names. Metadata
    // enrichment has no need to reach them, so fail closed rather than relying
    // on environment-specific DNS search domains.
    return host.contains('.');
  }

  static bool _isPublicAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return _isPublicIpv4(bytes);
    }

    if (address.type != InternetAddressType.IPv6 || bytes.length != 16) {
      return false;
    }

    if (_isIpv4MappedIpv6(bytes)) {
      return _isPublicIpv4(bytes.sublist(12));
    }

    // Only globally routed IPv6 unicast space is eligible for direct literal
    // metadata targets. DNS hostnames remain subject to the transport resolver.
    if ((bytes[0] & 0xe0) != 0x20) return false; // 2000::/3

    // RFC 3849 documentation prefix is intentionally non-routable.
    if (bytes[0] == 0x20 &&
        bytes[1] == 0x01 &&
        bytes[2] == 0x0d &&
        bytes[3] == 0xb8) {
      return false;
    }

    return true;
  }

  static bool _isIpv4MappedIpv6(List<int> bytes) {
    for (var index = 0; index < 10; index += 1) {
      if (bytes[index] != 0) return false;
    }
    return bytes[10] == 0xff && bytes[11] == 0xff;
  }

  static bool _isPublicIpv4(List<int> bytes) {
    if (bytes.length != 4) return false;
    final a = bytes[0];
    final b = bytes[1];
    final c = bytes[2];

    if (a == 0 || a == 10 || a == 127) return false;
    if (a == 100 && b >= 64 && b <= 127) return false; // RFC 6598
    if (a == 169 && b == 254) return false; // link-local
    if (a == 172 && b >= 16 && b <= 31) return false;
    if (a == 192 && b == 168) return false;

    // IETF protocol/documentation/non-routed special-purpose ranges.
    if (a == 192 && b == 0 && c == 0) return false;
    if (a == 192 && b == 0 && c == 2) return false;
    if (a == 198 && (b == 18 || b == 19)) return false;
    if (a == 198 && b == 51 && c == 100) return false;
    if (a == 203 && b == 0 && c == 113) return false;

    // Multicast and reserved/future-use space is not a public metadata target.
    if (a >= 224) return false;

    return true;
  }
}
