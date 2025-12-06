import 'package:sliding_window_limiter/src/rate_limit.dart';
import 'package:sliding_window_limiter/src/sliding_window.dart';
import 'package:sliding_window_limiter/src/storage.dart';

/// Sliding window rate limiter.
///
/// Uses a classic sliding window algorithm to smooth bursts while
/// honoring a maximum [limit] over a given [interval].
class SlidingWindowLimiter {
  /// Unique identifier for the subject being limited.
  final String id;

  /// Maximum number of tokens allowed per [interval].
  final int limit;

  /// Duration of the sliding window.
  final Duration interval;

  /// Backend used to persist and retrieve window state.
  final Storage storage;

  /// Creates a limiter that enforces [limit] over [interval] for [id].
  SlidingWindowLimiter({
    required this.id,
    required this.limit,
    required this.interval,
    required this.storage,
  });

  /// Attempts to consume [tokens] from the current window.
  ///
  /// Returns a [RateLimit] describing whether the request was accepted,
  /// how many tokens remain, and when to retry if rejected.
  Future<RateLimit> consume(int tokens) async {
    var window = await storage.fetch(id);
    if (window == null || _isWindowExpired(window)) {
      window = SlidingWindow(id: id, windowStartAt: DateTime.now());
    }

    final hitCount = _getUpdatedHitCount(window);
    final availableTokens = limit - hitCount;
    final waitSeconds = _getWaitTimeForTokens(limit, tokens, window);
    final accepted = tokens <= availableTokens;

    if (accepted) {
      window.hitCount = hitCount + tokens;
      window.windowStartAt = DateTime.now();
    }
    await storage.save(window, interval);
    return RateLimit(
      remainingTokens: availableTokens - (accepted ? tokens : 0),
      retryAfter: DateTime.now().add(waitSeconds),
      accepted: accepted,
      limit: limit,
    );
  }

  /// Whether the window is past its end time.
  bool _isWindowExpired(SlidingWindow window) {
    return DateTime.now().isAfter(window.windowStartAt.add(interval));
  }

  /// Returns the decayed hit count at the current moment.
  ///
  /// As time advances toward [windowEndAt], the effective hit count
  /// decreases linearly, implementing the sliding window behavior.
  double _getUpdatedHitCount(SlidingWindow window) {
    if (_isWindowExpired(window)) {
      return 0;
    }
    final now = DateTime.now();
    int windowInMilliseconds = interval.inMilliseconds;
    final elapsedInMilliseconds = now
        .difference(window.windowStartAt)
        .inMilliseconds;
    final decayFactor = elapsedInMilliseconds / windowInMilliseconds;
    final decayedHitCount = window.hitCount * (1 - decayFactor);
    return decayedHitCount;
  }

  /// Computes how long to wait until [tokens] can be accepted.
  ///
  /// [maxSize] is the window capacity (i.e. limit). If there are enough
  /// remaining tokens in the window, returns [Duration.zero].
  Duration _getWaitTimeForTokens(
    int maxSize,
    int tokens,
    SlidingWindow window,
  ) {
    assert(tokens > 0 && maxSize > 0 && tokens <= maxSize);
    final updatedHitCount = _getUpdatedHitCount(window);
    final remaining = maxSize - updatedHitCount;
    if (remaining >= tokens) {
      return Duration.zero;
    }
    int windowInMilliseconds = interval.inMilliseconds;
    double timeForEachToken = windowInMilliseconds / maxSize;
    final tokensNeeded = tokens - remaining;
    return Duration(milliseconds: (tokensNeeded * timeForEachToken).ceil());
  }
}
