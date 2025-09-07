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
    if (window == null || window.isExpired()) {
      window = SlidingWindow(
        id: id,
        windowStartAt: DateTime.now(),
        windowEndAt: DateTime.now().add(interval),
      );
    }

    final hitCount = window.getUpdatedHitCount();
    final availableTokens = limit - hitCount;
    final waitSeconds = window.getWaitTimeForTokens(limit, tokens);
    final accepted = tokens <= availableTokens;

    if (accepted) {
      window.hitCount += tokens;
      window.windowStartAt = DateTime.now();
      window.windowEndAt = DateTime.now().add(interval);
    }
    await storage.save(window);
    return RateLimit(
      remainingTokens: availableTokens - (accepted ? tokens : 0),
      retryAfter: DateTime.now().add(waitSeconds),
      accepted: accepted,
      limit: limit,
    );
  }
}
