import 'package:sliding_window_limiter/src/rate_limit.dart';
import 'package:sliding_window_limiter/src/sliding_window.dart';
import 'package:sliding_window_limiter/src/storage.dart';

/// Sliding window limiter.
class SlidingWindowLimiter {
  final String id;
  final int limit;
  final Duration interval;
  final Storage storage;

  SlidingWindowLimiter({
    required this.id,
    required this.limit,
    required this.interval,
    required this.storage,
  });

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
