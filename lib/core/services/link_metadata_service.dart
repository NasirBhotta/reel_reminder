import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;

class LinkMetadata {
  const LinkMetadata({
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    required this.domain,
  });

  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String domain;

  bool get hasPreview =>
      title != null ||
      description != null ||
      imageUrl != null ||
      siteName != null;
}

class LinkMetadataService {
  LinkMetadataService({HttpClient? client}) : _client = client ?? HttpClient() {
    _client
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 5)
      ..userAgent = 'ReelReminder/0.0.3 (+link-preview)';
  }

  static const _timeout = Duration(seconds: 8);
  static const _maxBytes = 512 * 1024;
  final HttpClient _client;

  Future<LinkMetadata?> fetch(Uri original) async {
    try {
      var uri = original;
      for (var redirects = 0; redirects <= 3; redirects++) {
        await _validatePublicUrl(uri);
        final request = await _client.getUrl(uri).timeout(_timeout);
        request
          ..followRedirects = false
          ..headers.set(
            HttpHeaders.acceptHeader,
            'text/html,application/xhtml+xml',
          )
          ..headers.set(HttpHeaders.acceptLanguageHeader, 'en,*;q=0.5');
        final response = await request.close().timeout(_timeout);

        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null || redirects == 3) return null;
          uri = uri.resolve(location);
          await response.drain<void>();
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>();
          return null;
        }
        final type = response.headers.contentType?.mimeType.toLowerCase();
        if (type != 'text/html' && type != 'application/xhtml+xml') {
          await response.drain<void>();
          return null;
        }

        final bytes = <int>[];
        await for (final chunk in response.timeout(_timeout)) {
          if (bytes.length + chunk.length > _maxBytes) return null;
          bytes.addAll(chunk);
        }
        return parse(
          utf8.decode(bytes, allowMalformed: true),
          pageUrl: uri,
          originalUrl: original,
        );
      }
    } catch (_) {
      // Preview failures never affect saving or opening the original URL.
    }
    return null;
  }

  LinkMetadata parse(String source, {required Uri pageUrl, Uri? originalUrl}) {
    final document = html_parser.parse(source);
    String? content(String selector) =>
        _clean(document.querySelector(selector)?.attributes['content']);

    final title =
        content('meta[property="og:title"]') ??
        content('meta[name="twitter:title"]') ??
        _clean(document.querySelector('title')?.text);
    final description =
        content('meta[property="og:description"]') ??
        content('meta[name="description"]') ??
        content('meta[name="twitter:description"]');
    final siteName = content('meta[property="og:site_name"]');
    final rawImage =
        content('meta[property="og:image:secure_url"]') ??
        content('meta[property="og:image"]') ??
        content('meta[name="twitter:image"]');
    String? imageUrl;
    if (rawImage != null) {
      final image = pageUrl.resolve(rawImage);
      if (image.scheme == 'https' && image.host.isNotEmpty) {
        imageUrl = image.toString();
      }
    }
    return LinkMetadata(
      title: title,
      description: description,
      imageUrl: imageUrl,
      siteName: siteName,
      domain: (originalUrl ?? pageUrl).host.toLowerCase(),
    );
  }

  String? _clean(String? value) {
    final clean = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean == null || clean.isEmpty) return null;
    return clean.length <= 500 ? clean : '${clean.substring(0, 497)}...';
  }

  Future<void> _validatePublicUrl(Uri uri) async {
    if (!const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 80 && uri.port != 443)) {
      throw const FormatException('Unsafe preview URL');
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost')) {
      throw const FormatException('Local preview URL');
    }
    final addresses = await InternetAddress.lookup(host).timeout(_timeout);
    if (addresses.isEmpty || addresses.any(_isPrivateAddress)) {
      throw const FormatException('Private preview address');
    }
  }

  bool _isPrivateAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      final first = bytes[0], second = bytes[1];
      return first == 0 ||
          first == 10 ||
          first == 127 ||
          (first == 100 && second >= 64 && second <= 127) ||
          (first == 169 && second == 254) ||
          (first == 172 && second >= 16 && second <= 31) ||
          (first == 192 && second == 168) ||
          (first == 198 && (second == 18 || second == 19)) ||
          first >= 224;
    }
    final allZero = bytes.every((byte) => byte == 0);
    final loopback =
        bytes.take(15).every((byte) => byte == 0) && bytes[15] == 1;
    final uniqueLocal = (bytes[0] & 0xfe) == 0xfc;
    final linkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80;
    final mappedV4 =
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 0xff &&
        bytes[11] == 0xff;
    return allZero ||
        loopback ||
        uniqueLocal ||
        linkLocal ||
        (mappedV4 &&
            _isPrivateAddress(
              InternetAddress.fromRawAddress(bytes.sublist(12)),
            ));
  }

  void close() => _client.close(force: true);
}
