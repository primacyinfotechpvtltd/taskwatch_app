/// Utility class for time and duration formatting
class FormatUtils {
  /// Format a DateTime to a 12-hour time string (e.g., "2:30 PM")
  static String formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
