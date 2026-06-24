class DurationUtils {
  /// Parses a string in `mm:hh` or `mm:hh:ss` format into a Duration.
  static Duration fromString(String input) {
    final parts = input.split(':').map((e) => int.tryParse(e)).toList();

    if (parts.any((e) => e == null)) {
      throw FormatException('Invalid number in time string');
    }

    if (parts.length == 2) {
      final minutes = parts[0]!;
      final hours = parts[1]!;
      return Duration(hours: hours, minutes: minutes);
    } else if (parts.length == 3) {
      final minutes = parts[0]!;
      final hours = parts[1]!;
      final seconds = parts[2]!;
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    } else {
      throw FormatException('Invalid format. Expected mm:hh or mm:hh:ss');
    }
  }

  /// Tries to parse a string into a Duration. Returns null if it fails.
  static Duration? tryParseDuration(String? durationStr) {
    if (durationStr == null) return null;

    try {
      var timeString = durationStr;
      bool isNegative = timeString.startsWith('-');

      if (isNegative) {
        timeString = timeString.substring(1); // Remove the negative sign
      }

      final parts = timeString.split(':');
      if (parts.length != 2) return null;

      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);

      if (hours == null || minutes == null) return null;

      var duration = Duration(hours: hours, minutes: minutes);
      return isNegative ? -duration : duration;
    } catch (_) {
      return null;
    }
  }

  /// Converts a Duration to a string in `mm:hh[:ss]` format.
  static String format(Duration duration, {bool includeSeconds = false}) {
    final minutes = duration.inMinutes % 60;
    final hours = duration.inHours;
    final mm = minutes.toString().padLeft(2, '0');
    final hh = hours.toString().padLeft(2, '0');

    if (includeSeconds) {
      final seconds = duration.inSeconds % 60;
      final ss = seconds.toString().padLeft(2, '0');
      return '$mm:$hh:$ss';
    }

    return '$mm:$hh';
  }

  /// Format a Duration to display as HH:MM
  static String formatDuration(Duration? duration) {
    if (duration == null) return '00:00';

    final isNegative = duration.isNegative;
    final posDuration = isNegative ? -duration : duration;

    final hours = posDuration.inHours;
    final minutes = posDuration.inMinutes.remainder(60);

    final formatted =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    return isNegative ? '-$formatted' : formatted;
  }

  /// Format duration in a human-readable format (e.g., "2h 30m")
  static String formatHumanReadable(Duration? duration) {
    if (duration == null) return '0m';

    final isNegative = duration.isNegative;
    final posDuration = isNegative ? -duration : duration;

    final days = posDuration.inDays;
    final hours = posDuration.inHours.remainder(24);
    final minutes = posDuration.inMinutes.remainder(60);
    final seconds = posDuration.inSeconds.remainder(60);

    final parts = <String>[];

    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0 && days == 0 && hours == 0) parts.add('${seconds}s');

    if (parts.isEmpty) return '0m';

    final result = parts.join(' ');
    return isNegative ? '-$result' : result;
  }

  /// Convert days, hours, minutes and seconds to a Duration
  static Duration fromParts({
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
  }) {
    return Duration(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }

  /// Parse a duration string in natural language format
  /// Supports formats like "2h 30m", "45m", "1d 6h", etc.
  static Duration? parseNaturalLanguage(String input) {
    if (input.isEmpty) return null;

    final regex = RegExp(r'(\d+)\s*([dhms])');
    final matches = regex.allMatches(input);

    if (matches.isEmpty) return null;

    int days = 0, hours = 0, minutes = 0, seconds = 0;

    for (final match in matches) {
      final value = int.parse(match.group(1)!);
      final unit = match.group(2);

      switch (unit) {
        case 'd':
          days += value;
          break;
        case 'h':
          hours += value;
          break;
        case 'm':
          minutes += value;
          break;
        case 's':
          seconds += value;
          break;
      }
    }

    return Duration(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }

  /// Add two durations safely (handles null values)
  static Duration? add(Duration? a, Duration? b) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return a + b;
  }

  /// Subtract two durations safely (handles null values)
  static Duration? subtract(Duration? a, Duration? b) {
    if (a == null) return b != null ? -b : null;
    if (b == null) return a;
    return a - b;
  }

  /// Format duration as seconds (e.g., 3661 becomes "01:01:01")
  static String formatFromSeconds(int seconds, {bool includeHours = true}) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (includeHours || hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  /// Get total duration in seconds
  static int toSeconds(Duration duration) {
    return duration.inSeconds;
  }

  /// Check if a duration is zero or null
  static bool isZeroOrNull(Duration? duration) {
    return duration == null || duration.inMicroseconds == 0;
  }
}
