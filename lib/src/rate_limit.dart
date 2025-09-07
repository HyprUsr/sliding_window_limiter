/// Represents the result of a rate limit check.
class RateLimit {
  /// Tokens still available in the current window.
  final double remainingTokens;

  /// The earliest time when a rejected request can be retried.
  final DateTime retryAfter;

  /// Whether the request was accepted within the current window.
  final bool accepted;

  /// The configured maximum tokens per window.
  final int limit;

  /// This code selection performs a specific operation or functionality.
  ///
  /// Please refer to the code for implementation details.
  ///
  /// - Add a more detailed description of what the code does.
  /// - Document parameters, return values, and any exceptions thrown if applicable.
  /// - Include usage examples if necessary.
  RateLimit({
    required this.remainingTokens,
    required this.retryAfter,
    required this.accepted,
    required this.limit,
  });

  /// Convenience getter for how long to wait until [retryAfter].
  Duration get waitTime {
    final now = DateTime.now();
    if (retryAfter.isAfter(now)) {
      return retryAfter.difference(now);
    }
    return Duration.zero;
  }
}
