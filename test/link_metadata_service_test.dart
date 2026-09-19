import 'package:flutter_test/flutter_test.dart';
import 'package:reel_reminder/core/services/link_metadata_service.dart';

void main() {
  late LinkMetadataService service;

  setUp(() => service = LinkMetadataService());
  tearDown(() => service.close());

  test('prefers Open Graph and resolves a relative secure thumbnail', () {
    final metadata = service.parse('''
      <html><head>
        <title>HTML title</title>
        <meta property="og:title" content="Readable video title">
        <meta property="og:description" content="A useful description">
        <meta property="og:image" content="/images/preview.jpg">
        <meta property="og:site_name" content="Example Video">
      </head></html>
      ''', pageUrl: Uri.parse('https://example.com/watch/1'));

    expect(metadata.title, 'Readable video title');
    expect(metadata.description, 'A useful description');
    expect(metadata.thumbnailUrl, 'https://example.com/images/preview.jpg');
    expect(metadata.siteName, 'Example Video');
    expect(metadata.domain, 'example.com');
  });

  test('uses JSON-LD before HTML fallback fields', () {
    final metadata = service.parse('''
      <html><head>
        <script type="application/ld+json">
          {"@type":"VideoObject","name":"JSON-LD video","description":"Video description","image":"https://cdn.example.com/video.jpg"}
        </script>
        <title>HTML fallback</title>
      </head></html>
      ''', pageUrl: Uri.parse('https://example.com/video'));

    expect(metadata.title, 'JSON-LD video');
    expect(metadata.description, 'Video description');
    expect(metadata.thumbnailUrl, 'https://cdn.example.com/video.jpg');
  });

  test('missing metadata returns a domain-only fallback', () {
    final metadata = service.parse(
      '<html><body>Nothing useful</body></html>',
      pageUrl: Uri.parse('https://example.com/plain'),
    );

    expect(metadata.hasPreview, isFalse);
    expect(metadata.domain, 'example.com');
  });

  test('malformed JSON-LD does not hide HTML metadata', () {
    final metadata = service.parse('''
      <html><head>
        <script type="application/ld+json">{broken</script>
        <title>Still readable</title>
        <meta name="description" content="Still useful">
      </head></html>
      ''', pageUrl: Uri.parse('https://example.com/article'));

    expect(metadata.title, 'Still readable');
    expect(metadata.description, 'Still useful');
  });
}
