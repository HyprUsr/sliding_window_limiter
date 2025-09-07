# Dart implementation for Sliding Window Limiter

A lightweight, storage‑agnostic sliding‑window rate limiter for Dart.
Provide your own storage (e.g., Redis, in‑memory, database) via a tiny
`Storage` interface, and call `consume(tokens)` to check and record usage.

## Install

- With Dart: `dart pub add sliding_window_limiter`
- With Flutter: `flutter pub add sliding_window_limiter`

## Quick start

```dart
import 'dart:convert';
import 'package:sliding_window_limiter/sliding_window_limiter.dart';

Future<void> main() async {
  final limiter = SlidingWindowLimiter(
    id: 'client-IP-or-user-id',
    limit: 120,                       // max tokens per interval
    interval: Duration(minutes: 1),   // sliding window interval
    storage: RedisStorage(),          // your Storage implementation
  );

  // Request 1 token for this operation
  final result = await limiter.consume(1);

  if (!result.accepted) {
    // Inform caller to retry later
    print('Retry after: ${result.retryAfter}');
    print('Wait time: ${result.waitTime.inSeconds} seconds');
    return;
  }

  print('Remaining tokens: ${result.remainingTokens}');
}

// Example storage (replace with real Redis client)
class RedisStorage implements Storage {
  @override
  Future<void> save(SlidingWindow window) async {
    // Persist window.toJson() and set TTL to:
    //   window.windowEndAt.difference(DateTime.now())
  }

  @override
  Future<SlidingWindow?> fetch(String id) async {
    final data = null; // Load JSON string by id
    if (data == null) return null;
    return SlidingWindow.fromJson(jsonDecode(data));
  }
}
```

If you just need an in‑memory example for tests, this minimal storage works:

```dart
class MemoryStorage implements Storage {
  final Map<String, SlidingWindow> _store = {};

  @override
  Future<void> save(SlidingWindow window) async {
    _store[window.id] = window;
  }

  @override
  Future<SlidingWindow?> fetch(String id) async {
    final w = _store[id];
    if (w == null || w.isExpired()) return null;
    return w;
  }
}
```

## API

- `SlidingWindowLimiter`:
  - `id`: logical key (e.g., user ID, IP).
  - `limit`: max tokens allowed per `interval`.
  - `interval`: sliding window duration.
  - `storage`: implementation of `Storage`.
  - `Future<RateLimit> consume(int tokens)`: attempts to consume `tokens`.

- `RateLimit` result:
  - `accepted`: whether tokens were accepted.
  - `remainingTokens`: remaining capacity in current window (double).
  - `retryAfter`: timestamp when enough capacity is available.
  - `waitTime`: convenience `Duration` until `retryAfter` (zero if available now).
  - `limit`: configured max tokens per interval.

- `Storage` interface:
  - `Future<void> save(SlidingWindow window)`
  - `Future<SlidingWindow?> fetch(String id)`

Notes:
- `tokens` must be > 0 and <= `limit`.
- Use your storage’s TTL equal to `windowEndAt - now` to auto‑expire windows.
- The algorithm decays usage continuously within the window for smooth limiting.

## License

Apache-2.0 — see `LICENSE`.
