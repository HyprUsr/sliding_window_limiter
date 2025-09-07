/// State of a sliding window.
class SlidingWindow {
  final String id;
  DateTime windowStartAt;
  DateTime windowEndAt;
  double hitCount;

  SlidingWindow({
    required this.id,
    required this.windowStartAt,
    required this.windowEndAt,
    this.hitCount = 0,
  });

  bool isExpired() => DateTime.now().isAfter(windowEndAt);

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'windowStartAt': windowStartAt.toIso8601String(),
    'windowEndAt': windowEndAt.toIso8601String(),
    'hitCount': hitCount,
  };

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
