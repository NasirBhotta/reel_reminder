enum ContentPlatform {
  tiktok('TikTok'),
  instagram('Instagram'),
  facebook('Facebook'),
  youtube('YouTube'),
  x('X'),
  reddit('Reddit'),
  website('Website');

  const ContentPlatform(this.label);
  final String label;
}

class PlatformDetector {
  static ContentPlatform detect(Uri uri) {
    final host = uri.host.toLowerCase();
    bool matches(String domain) => host == domain || host.endsWith('.$domain');
    if (matches('tiktok.com')) return ContentPlatform.tiktok;
    if (matches('instagram.com')) return ContentPlatform.instagram;
    if (matches('facebook.com') || matches('fb.watch')) {
      return ContentPlatform.facebook;
    }
    if (matches('youtube.com') || matches('youtu.be')) {
      return ContentPlatform.youtube;
    }
    if (matches('x.com') || matches('twitter.com')) return ContentPlatform.x;
    if (matches('reddit.com') || matches('redd.it')) {
      return ContentPlatform.reddit;
    }
    return ContentPlatform.website;
  }
}

class UrlParser {
  static Uri parse(String text) {
    final matches = RegExp(
      r'''https?://[^\s<>"“”]+''',
      caseSensitive: false,
    ).allMatches(text);
    for (final match in matches) {
      var candidate = match.group(0)!;
      // Remove prose wrappers, keeping balanced brackets inside the URL.
      while (true) {
        final before = candidate;
        candidate = candidate.replaceFirst(RegExp(r"[.,!?:;'’]+$"), '');
        for (final pair in const [('(', ')'), ('[', ']'), ('{', '}')]) {
          if (candidate.endsWith(pair.$2) &&
              pair.$2.allMatches(candidate).length >
                  pair.$1.allMatches(candidate).length) {
            candidate = candidate.substring(0, candidate.length - 1);
          }
        }
        if (candidate == before) break;
      }
      try {
        final uri = Uri.tryParse(candidate);
        if (uri == null ||
            !const ['http', 'https'].contains(uri.scheme) ||
            uri.userInfo.isNotEmpty ||
            candidate.length > 8192 ||
            RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(candidate) ||
            RegExp(r'[\x00-\x20\\]').hasMatch(candidate)) {
          continue;
        }
        final host = uri.host.toLowerCase();
        final labels = host.split('.');
        if (RegExp(r'^[0-9.]+$').hasMatch(host) &&
            (labels.length != 4 ||
                labels.any(
                  (part) => int.tryParse(part) == null || int.parse(part) > 255,
                ))) {
          continue;
        }
        if (host.length > 253 ||
            labels.length < 2 ||
            labels.any(
              (label) => !RegExp(
                r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
              ).hasMatch(label),
            ) ||
            uri.port < 1 ||
            uri.port > 65535) {
          continue;
        }
        return uri.replace(host: host, path: uri.path.isEmpty ? '/' : uri.path);
      } on FormatException {
        // A malformed candidate must not hide a later valid link.
      }
    }
    throw const FormatException(
      'Share text containing a valid http or https link.',
    );
  }
}

enum DateFilter { today, yesterday, week, month, all }

class DateHistory {
  static DateTime day(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static bool includes(DateTime value, DateFilter filter, DateTime now) {
    final today = day(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final start = switch (filter) {
      DateFilter.today => today,
      DateFilter.yesterday => DateTime(today.year, today.month, today.day - 1),
      DateFilter.week => DateTime(
        today.year,
        today.month,
        today.day - today.weekday + 1,
      ),
      DateFilter.month => DateTime(today.year, today.month),
      DateFilter.all => null,
    };
    final end = filter == DateFilter.yesterday ? today : tomorrow;
    return start == null || (!value.isBefore(start) && value.isBefore(end));
  }

  static String group(DateTime value, DateTime now) {
    if (includes(value, DateFilter.today, now)) return 'Today';
    if (includes(value, DateFilter.yesterday, now)) return 'Yesterday';
    if (includes(value, DateFilter.week, now)) return 'This Week';
    if (includes(value, DateFilter.month, now)) return 'This Month';
    return 'Older';
  }
}

class DuplicateGuard {
  final Map<String, DateTime> _recent = {};
  bool accept(String url, DateTime now) {
    _recent.removeWhere(
      (_, time) => now.difference(time).abs() >= const Duration(seconds: 8),
    );
    if (_recent.containsKey(url)) return false;
    _recent[url] = now;
    return true;
  }

  void forget(String url) => _recent.remove(url);
}
