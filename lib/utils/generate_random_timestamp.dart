import 'dart:math';

/// Generates a list of well-distributed random timestamps within a given duration.
List<Duration> generateRandomTimestamps({
  required Duration within,
  required int count,
}) {
  final totalSeconds = within.inSeconds;

  if (count <= 0) {
    throw ArgumentError('Count must be > 0 (got $count)');
  }
  if (totalSeconds <= 1) {
    throw ArgumentError('Duration must be > 1 second (got $totalSeconds)');
  }

  final random = Random();
  final startBoundary = max(1, (totalSeconds * 0.1).round());
  final endBoundary = max(startBoundary + 1, (totalSeconds * 0.9).round());
  final usableRange = endBoundary - startBoundary;
  final minSpacing = max(1, (totalSeconds / (count + 2)).round());

  // If not enough room for spaced randoms, fallback to evenly spaced values
  if (usableRange < count * minSpacing) {
    final step = usableRange / (count + 1);
    return List.generate(
      count,
      (i) => Duration(seconds: (startBoundary + step * (i + 1)).round()),
    );
  }

  final Set<int> selectedSeconds = {};
  int attempts = 0, maxAttempts = count * 10;

  while (selectedSeconds.length < count && attempts < maxAttempts) {
    final candidate = random.nextInt(usableRange) + startBoundary;
    if (selectedSeconds.every((s) => (s - candidate).abs() >= minSpacing)) {
      selectedSeconds.add(candidate);
    }
    attempts++;
  }

  // Fill remaining with evenly spaced if random attempts failed
  if (selectedSeconds.length < count) {
    final remaining = count - selectedSeconds.length;
    final step = usableRange / (remaining + 1);
    for (int i = 1; i <= remaining; i++) {
      final candidate = (startBoundary + step * i).round();
      if (selectedSeconds.every((s) => (s - candidate).abs() >= minSpacing)) {
        selectedSeconds.add(candidate);
      }
    }
  }

  // Fix: Sort the seconds list, then convert each second to Duration
  final sortedSeconds = selectedSeconds.toList()..sort();
  return sortedSeconds.map((s) => Duration(seconds: s)).toList();
}
