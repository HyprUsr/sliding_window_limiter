/// State of a sliding window.
///
/// Tracks time bounds and the number of tokens recorded in the window.
class SlidingWindow {
  /// Application‑defined identifier used to group events per subject.
  final String id;

  /// Inclusive start of the current window.
  DateTime windowStartAt;

  /// Exclusive end of the current window.
  DateTime windowEndAt;

  /// Accumulated token count within the window.
  double hitCount;

  /// Creates a sliding window starting at [windowStartAt] and ending at
  /// [windowEndAt], with an initial [hitCount] (default `0`).
  SlidingWindow({
    required this.id,
    required this.windowStartAt,
    required this.windowEndAt,
    this.hitCount = 0,
  });

  /// Whether the window is past its end time.
  bool isExpired() => DateTime.now().isAfter(windowEndAt);

  /// Returns the decayed hit count at the current moment.
  ///
  /// As time advances toward [windowEndAt], the effective hit count
  /// decreases linearly, implementing the sliding window behavior.
  double getUpdatedHitCount() {
    if (isExpired()) {
      return 0;
    }
    final now = DateTime.now();
    int windowInMicroseconds = windowEndAt
        .difference(windowStartAt)
        .inMicroseconds;
    double hitCountPerMicrosecond = hitCount / windowInMicroseconds;
    int elapsedMicroseconds = windowEndAt.difference(now).inMicroseconds;
    return hitCountPerMicrosecond * elapsedMicroseconds;
  }

  /// Computes how long to wait until [tokens] can be accepted.
  ///
  /// [maxSize] is the window capacity (i.e. limit). If there are enough
  /// remaining tokens in the window, returns [Duration.zero].
  Duration getWaitTimeForTokens(int maxSize, int tokens) {
    assert(tokens > 0 && maxSize > 0 && tokens <= maxSize);
    final updatedHitCount = getUpdatedHitCount();
    final remaining = maxSize - updatedHitCount;
    if (remaining >= tokens) {
      return Duration.zero;
    }
    int windowInMilliseconds = windowEndAt
        .difference(windowStartAt)
        .inMilliseconds;
    double timeForEachToken = windowInMilliseconds / maxSize;
    final tokensNeeded = tokens - remaining;
    return Duration(milliseconds: (tokensNeeded * timeForEachToken).ceil());
  }

  /// Serializes this window to a JSON‑compatible map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'windowStartAt': windowStartAt.toIso8601String(),
    'windowEndAt': windowEndAt.toIso8601String(),
    'hitCount': hitCount,
  };

  /// Deserializes a [SlidingWindow] from a JSON‑compatible map.
  static SlidingWindow fromJson(Map<String, dynamic> json) {
    final win = SlidingWindow(
      id: json['id'],
      windowStartAt: DateTime.parse(json['windowStartAt']),
      windowEndAt: DateTime.parse(json['windowEndAt']),
      hitCount: double.tryParse(json['hitCount'].toString()) ?? 0,
    );
    return win;
  }
}
