import 'dart:convert';

import 'package:sliding_window_limiter/sliding_window_limiter.dart';

Future<void> main() async {
  String rateLimitId = 'client-IP-address-or-user-id';

  final limiter = SlidingWindowLimiter(
    id: rateLimitId,
    limit: 120,
    interval: Duration(minutes: 1),
    storage: RedisStorage(),
  );
  final rateLimit = await limiter.consume(1);
  if (!rateLimit.accepted) {
    print('Retry after: ${rateLimit.retryAfter}');
    print('Wait time: ${rateLimit.waitTime.inSeconds} seconds');
    throw Exception('Rate limit exceeded.');
  }
  print('Remaining tokens: ${rateLimit.remainingTokens}');
}

class RedisStorage implements Storage {
  @override
  Future<void> save(SlidingWindow window) async {
    // Simulate saving to Redis
    // use ttl: window.windowEndAt.difference(DateTime.now())
  }

  @override
  Future<SlidingWindow?> fetch(String id) async {
    final data = null; // Simulate fetching from Redis
    if (data == null) return null;
    return SlidingWindow.fromJson(jsonDecode(data));
  }
}
