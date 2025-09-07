/// Represents the result of a rate limit check.
class RateLimit {
  final double remainingTokens;
  final DateTime retryAfter;
  final bool accepted;
  final int limit;

  RateLimit({
    required this.remainingTokens,
    required this.retryAfter,
    required this.accepted,
    required this.limit,
  });

  Duration get waitTime {
    final now = DateTime.now();
    if (retryAfter.isAfter(now)) {
      return retryAfter.difference(now);
    }
    return Duration.zero;
  }
}
