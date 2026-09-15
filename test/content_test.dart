import 'package:flutter_test/flutter_test.dart';
import 'package:reel_reminder/core/utils/content.dart';

void main() {
  group('platform detection', () {
    final cases = {
      'vm.tiktok.com': ContentPlatform.tiktok,
      'www.instagram.com': ContentPlatform.instagram,
      'fb.watch': ContentPlatform.facebook,
      'm.facebook.com': ContentPlatform.facebook,
      'youtu.be': ContentPlatform.youtube,
      'www.youtube.com': ContentPlatform.youtube,
      'twitter.com': ContentPlatform.x,
      'x.com': ContentPlatform.x,
      'old.reddit.com': ContentPlatform.reddit,
      'reddit.com.attacker.net': ContentPlatform.website,
      'notyoutube.com': ContentPlatform.website,
    };
    for (final entry in cases.entries) {
      test(
        entry.key,
        () => expect(
          PlatformDetector.detect(Uri.parse('https://${entry.key}/post')),
          entry.value,
        ),
      );
    }
  });
  group('URL parsing', () {
    test(
      'extracts and normalizes without changing case-sensitive path or query',
      () {
        expect(
          UrlParser.parse(
            'Check this https://WWW.Instagram.com/Reel/AbC?igsh=XYZ.',
          ).toString(),
          'https://www.instagram.com/Reel/AbC?igsh=XYZ',
        );
      },
    );
    test('balanced parentheses survive prose wrapping', () {
      expect(
        UrlParser.parse('(https://example.com/wiki/Test_(thing))').path,
        '/wiki/Test_(thing)',
      );
    });
    test('rejects unsafe schemes, missing URLs, and credentials', () {
      for (final value in [
        'hello',
        'javascript:alert(1)',
        'file:///tmp/a',
        'https://user:pass@example.com',
      ]) {
        expect(() => UrlParser.parse(value), throwsFormatException);
      }
    });
  });
  group('local date history', () {
    final now = DateTime(2026, 9, 15, 12);
    test('midnight boundaries', () {
      expect(DateHistory.group(DateTime(2026, 9, 15), now), 'Today');
      expect(
        DateHistory.group(DateTime(2026, 9, 14, 23, 59), now),
        'Yesterday',
      );
      expect(
        DateHistory.includes(DateTime(2026, 9, 16), DateFilter.today, now),
        false,
      );
    });
    test('week begins Monday and month excludes previous month', () {
      expect(
        DateHistory.includes(DateTime(2026, 9, 13), DateFilter.week, now),
        false,
      );
      expect(
        DateHistory.includes(DateTime(2026, 9, 14), DateFilter.week, now),
        true,
      );
      expect(
        DateHistory.includes(DateTime(2026, 8, 31), DateFilter.month, now),
        false,
      );
      expect(
        DateHistory.group(DateTime(2026, 9, 14), DateTime(2026, 9, 17)),
        'Earlier This Week',
      );
    });
    test('year rollover', () {
      expect(
        DateHistory.group(DateTime(2025, 12, 31, 20), DateTime(2026, 1, 1)),
        'Yesterday',
      );
    });
  });
  test('duplicates suppressed briefly, retry and later saves allowed', () {
    final guard = DuplicateGuard();
    final now = DateTime(2026);
    expect(guard.accept('url', now), true);
    expect(guard.accept('url', now.add(const Duration(seconds: 7))), false);
    expect(guard.accept('url', now.add(const Duration(seconds: 8))), true);
    guard.forget('url');
    expect(guard.accept('url', now.add(const Duration(seconds: 9))), true);
  });
}
