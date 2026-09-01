/// Utility class for time and duration formatting
class FormatUtils {
  /// Safely parse an Odoo datetime string (which is stored in UTC without timezone offset)
  /// and convert it to local device timezone.
  static DateTime parseOdooDateTime(dynamic value) {
    if (value == null || value == false) return DateTime.now();
    if (value is DateTime) return value.isUtc ? value.toLocal() : value;
    if (value is String) {
      String str = value.trim();
      if (str.isEmpty) return DateTime.now();

      // If it already ends with 'Z' or has timezone offset like +05:30 or -04:00
      if (str.endsWith('Z') || RegExp(r'[+-]\d{2}(:?\d{2})?$').hasMatch(str)) {
        try {
          return DateTime.parse(str).toLocal();
        } catch (_) {}
      }

      // If format is date only 'YYYY-MM-DD', parse directly
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str)) {
        try {
          return DateTime.parse(str);
        } catch (_) {}
      }

      // Odoo standard datetime is 'YYYY-MM-DD HH:mm:ss' in UTC.
      // Replace space with 'T' and append 'Z' so DateTime.parse treats it as UTC.
      final isoStr = str.contains('T') ? str : str.replaceAll(' ', 'T');
      final utcIso = isoStr.endsWith('Z') ? isoStr : '${isoStr}Z';
      try {
        return DateTime.parse(utcIso).toLocal();
      } catch (_) {
        try {
          return DateTime.parse(str).toLocal();
        } catch (_) {
          return DateTime.now();
        }
      }
    }
    return DateTime.now();
  }

  /// Safely parse an optional Odoo datetime string. Returns null if invalid or missing.
  static DateTime? tryParseOdooDateTime(dynamic value) {
    if (value == null || value == false) return null;
    if (value is DateTime) return value.isUtc ? value.toLocal() : value;
    if (value is String) {
      String str = value.trim();
      if (str.isEmpty) return null;

      if (str.endsWith('Z') || RegExp(r'[+-]\d{2}(:?\d{2})?$').hasMatch(str)) {
        try {
          return DateTime.parse(str).toLocal();
        } catch (_) {}
      }

      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str)) {
        try {
          return DateTime.parse(str);
        } catch (_) {}
      }

      final isoStr = str.contains('T') ? str : str.replaceAll(' ', 'T');
      final utcIso = isoStr.endsWith('Z') ? isoStr : '${isoStr}Z';
      try {
        return DateTime.parse(utcIso).toLocal();
      } catch (_) {
        try {
          return DateTime.parse(str).toLocal();
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  /// Format a DateTime to a 12-hour time string (e.g., "2:30 PM")
  static String formatTime(DateTime dateTime) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Format last message time for chat list (Today: 10:07 AM, Yesterday: Yesterday, Older: 01/09)
  static String formatChatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final dt = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(messageDate).inDays;

    if (diffDays == 0) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (diffDays < 7 && diffDays > 0) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dt.weekday - 1];
    } else {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month';
    }
  }

  /// Format a duration to HH:MM:SS format
  static String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Format a duration to Xh Ym format
  static String formatTimeHM(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    return '${hours}h ${minutes}m';
  }

  /// Strip HTML tags and format text to plain text with proper newlines and spacing
  static String cleanHtml(String? html) {
    if (html == null || html.isEmpty) return '';

    String result = html;

    // 1. Decode common HTML entities
    result = result
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // 2. Replace block-level opening tags with appropriate spacing/newlines
    result = result
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<tr[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<td[^>]*>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<th[^>]*>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<h[1-6][^>]*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
        .replaceAll(RegExp(r'<ul[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<ol[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<blockquote[^>]*>', caseSensitive: false), '\n» ')
        .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n---\n');

    // 3. Replace block-level closing tags with appropriate newlines or spaces
    result = result
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</td>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</tr>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</th>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</ul>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</ol>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</blockquote>', caseSensitive: false), '\n');

    // 4. Strip all remaining HTML tags
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    // 5. Normalise line endings and consecutive whitespace
    result = result.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Replace lines containing only whitespace (e.g. spaces/tabs) with just a single newline
    result = result.replaceAll(RegExp(r'\n[ \t]+\n'), '\n\n');

    // Collapse 3 or more consecutive newlines down to max 2 newlines
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return result.trim();
  }
}
