class TextUtils {
  static String parseHtmlToPlainText(String html) {
    if (html.isEmpty) {
      return '';
    }
    String text = html;
    // Remove common HTML tags
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
    // Remove inline formatting tags
    text = text.replaceAll(RegExp(r'<b>|</b>|<strong>|</strong>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<i>|</i>|<em>|</em>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<u>|</u>', caseSensitive: false), '');
    // Remove any other HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode HTML entities
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    // Clean up whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static String extractYearFromStartDate(String startDate) {
    final match = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{1,4})$',
    ).firstMatch(startDate.trim());
    if (match == null) {
      return "~";
    }
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    if (day > 31 || month > 12 || year == 0) {
      return "~";
    }
    // Provider dates use zero for unknown components; do not fill them in.
    if (day != 0 && month != 0) {
      final date = DateTime.utc(year, month, day);
      if (date.day != day || date.month != month) {
        return "~";
      }
    }
    return year.toString();
  }

  static List<String> formatISO8601DateTime(String isoDateTime) {
    if (isoDateTime.isEmpty) {
      return ["~", "~", "~"];
    }
    final dateTime = DateTime.parse(isoDateTime);
    return [
      "${dateTime.day != 0 ? dateTime.day : "~"}",
      "${dateTime.month != 0 ? dateTime.month : "~"}",
      "${dateTime.year != 0 ? dateTime.year : "~"}",
    ];
  }

  static String formatMilliseconds(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static List<String> capitalizeList(List<String> list) {
    return list.map(capitalize).toList();
  }

  static String extractRepoName(String repoUrl) {
    try {
      final uri = Uri.parse(repoUrl);
      final hostname = uri.host.toLowerCase();

      final paths = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (hostname == 'raw.githubusercontent.com' || hostname == 'gist.githubusercontent.com') {
        return paths.isNotEmpty ? capitalize(paths.first) : 'GitHub Repo';
      }

      if (hostname.contains('github.io') || hostname.contains('gitlab.io')) {
        final username = hostname.split('.').first;
        return capitalize(username.replaceAll('-', ' '));
      }

      final domainParts = hostname.replaceFirst('www.', '').split('.');
      if (domainParts.length >= 2) {
        final mainDomain = domainParts[domainParts.length - 2];
        return capitalize(mainDomain);
      }
      return 'Custom Repo';
    } catch (e) {
      // Fallback if the URL is completely malformed or unparseable
      return 'Unknown Repo';
    }
  }

  static String capitalize(String str) {
    return str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : str;
  }
}
