/// State of a sliding window.
///
/// Tracks time bounds and the number of tokens recorded in the window.
class SlidingWindow {
  /// Application‑defined identifier used to group events per subject.
  final String id;

  /// Inclusive start of the current window.
  DateTime windowStartAt;

  /// Accumulated token count within the window.
  double hitCount;

  /// Creates a sliding window starting at [windowStartAt] and ending at
  /// [windowEndAt], with an initial [hitCount] (default `0`).
  SlidingWindow({
    required this.id,
    required this.windowStartAt,
    this.hitCount = 0,
  });

  /// Serializes this window to a JSON‑compatible map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'windowStartAt': windowStartAt.toIso8601String(),
    'hitCount': hitCount,
  };

  /// Deserializes a [SlidingWindow] from a JSON‑compatible map.
  static SlidingWindow fromJson(Map<String, dynamic> json) {
    final win = SlidingWindow(
      id: json['id'],
      windowStartAt: DateTime.parse(json['windowStartAt']),
      hitCount: double.tryParse(json['hitCount'].toString()) ?? 0,
    );
    return win;
  }
}
