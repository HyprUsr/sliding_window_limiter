import 'package:sliding_window_limiter/sliding_window_limiter.dart';
import 'package:test/test.dart';

SlidingWindowLimiter buildLimiter({
  String id = 'client-IP-address-or-user-id',
  int limit = 120,
  Duration interval = const Duration(minutes: 1),
  Storage? storage,
}) =>
    SlidingWindowLimiter(
      id: id,
      limit: limit,
      interval: interval,
      storage: storage ?? MemoryStorage(),
    );

void main() {
  group('Sliding window limiter basics', () {
    test('Initiation test', () {
      final limiter = buildLimiter();
      expect(limiter, isNotNull);
      expect(limiter.id, 'client-IP-address-or-user-id');
      expect(limiter.limit, 120);
      expect(limiter.interval, const Duration(minutes: 1));
      expect(limiter.storage, isA<MemoryStorage>());
    });

    test('Successfully consume tokens', () async {
      final limiter = buildLimiter();
      final rateLimit = await limiter.consume(1);
      expect(rateLimit.accepted, isTrue);
      expect(rateLimit.remainingTokens.toInt(), 119);
      expect(rateLimit.limit, 120);
      expect(rateLimit.waitTime.inSeconds, 0);
    });

    test('Consume more than limit', () async {
      final limiter = buildLimiter();
      await limiter.consume(120);
      final rateLimit = await limiter.consume(1);
      expect(rateLimit.accepted, isFalse);
      expect(rateLimit.remainingTokens.toInt(), 0);
      expect(rateLimit.limit, 120);
      expect(rateLimit.waitTime.inMicroseconds, greaterThan(0));
    });

    test('Consume with wait time', () async {
      final limiter = buildLimiter();
      await limiter.consume(120);
      await Future.delayed(const Duration(seconds: 1));
      final rateLimit = await limiter.consume(2);
      expect(rateLimit.accepted, isTrue);
      expect(rateLimit.waitTime.inMicroseconds, 0);
      expect(rateLimit.remainingTokens, lessThan(1));
    });

    test('Consume more than limit with wait time', () async {
      final limiter = buildLimiter();
      await limiter.consume(120);
      await Future.delayed(const Duration(seconds: 1));
      final rateLimit = await limiter.consume(3);
      expect(rateLimit.accepted, isFalse);
      expect(rateLimit.waitTime.inSeconds, lessThan(1));
      expect(rateLimit.remainingTokens, lessThan(3));
    });
  });

  group('Edge cases and limits', () {
    test('Rejects invalid token counts', () async {
      final limiter = buildLimiter(limit: 5);
      await expectLater(limiter.consume(0), throwsA(isA<AssertionError>()));
      await expectLater(limiter.consume(6), throwsA(isA<AssertionError>()));
    });

    test('Resets capacity after the window expires', () async {
      final limiter = buildLimiter(
        limit: 3,
        interval: const Duration(milliseconds: 60),
      );
      await limiter.consume(3);
      await Future.delayed(const Duration(milliseconds: 70));

      final rateLimit = await limiter.consume(3);
      expect(rateLimit.accepted, isTrue);
      expect(rateLimit.remainingTokens, 0);
      expect(rateLimit.waitTime, Duration.zero);
    });

    test('Shares state across limiter instances', () async {
      final sharedStorage = MemoryStorage();
      final firstLimiter = buildLimiter(
        id: 'shared',
        limit: 3,
        storage: sharedStorage,
      );
      final secondLimiter = buildLimiter(
        id: 'shared',
        limit: 3,
        storage: sharedStorage,
      );

      await firstLimiter.consume(2);
      final rateLimit = await secondLimiter.consume(2);

      expect(rateLimit.accepted, isFalse);
      expect(rateLimit.remainingTokens, closeTo(1, 0.2));
      expect(rateLimit.waitTime, isNot(Duration.zero));
    });

    test(
      'Allows partial refill inside the interval instead of over limiting',
      () async {
        final limiter = buildLimiter(
          limit: 10,
          interval: const Duration(milliseconds: 100),
        );

        await limiter.consume(10);
        await Future.delayed(const Duration(milliseconds: 60));

        final partiallyRefilled = await limiter.consume(6);
        expect(partiallyRefilled.accepted, isTrue);
        expect(partiallyRefilled.remainingTokens, closeTo(1, 1));

        await Future.delayed(const Duration(milliseconds: 10));
        final followUp = await limiter.consume(1);
        expect(followUp.accepted, isTrue);
        expect(followUp.waitTime, Duration.zero);
      },
    );
  });

  group('Negative and boundary scenarios', () {
    test('Exact limit accepted once then rejected immediately after', () async {
      final limiter = buildLimiter(
        limit: 3,
        interval: const Duration(milliseconds: 100),
      );
      final first = await limiter.consume(3);
      final second = await limiter.consume(1);

      expect(first.accepted, isTrue);
      expect(first.remainingTokens, 0);
      expect(second.accepted, isFalse);
      expect(second.waitTime, isNot(Duration.zero));
    });

    test('Rejected request does not increase hit count', () async {
      final storage = MemoryStorage();
      final limiter = buildLimiter(
        limit: 2,
        interval: const Duration(milliseconds: 100),
        storage: storage,
      );

      await limiter.consume(2); // fill the window
      await limiter.consume(1); // should be rejected

      final stored = await storage.fetch(limiter.id);
      expect(stored, isNotNull);
      expect(stored!.hitCount, closeTo(2, 0.01));
    });

    test('Different IDs remain isolated', () async {
      final storage = MemoryStorage();
      final first = buildLimiter(id: 'a', limit: 2, storage: storage);
      final second = buildLimiter(id: 'b', limit: 2, storage: storage);

      await first.consume(2);
      final bFirst = await second.consume(1);
      final aReject = await first.consume(1);
      final bFollowUp = await second.consume(1);

      expect(bFirst.accepted, isTrue);
      expect(aReject.accepted, isFalse);
      expect(bFollowUp.accepted, isTrue);
      expect(bFollowUp.waitTime, Duration.zero);
    });

    test('Retry after is in the future when rejected', () async {
      final limiter = buildLimiter(
        limit: 1,
        interval: const Duration(milliseconds: 80),
      );
      await limiter.consume(1);

      final rejected = await limiter.consume(1);
      expect(rejected.accepted, isFalse);
      expect(rejected.retryAfter.isAfter(DateTime.now()), isTrue);
      expect(rejected.waitTime, isNot(Duration.zero));
    });

    test('Expired windows are dropped when fetched again', () async {
      final storage = MemoryStorage();
      final limiter = buildLimiter(
        limit: 1,
        interval: const Duration(milliseconds: 30),
        storage: storage,
      );

      await limiter.consume(1);
      await Future.delayed(const Duration(milliseconds: 40));

      final next = await limiter.consume(1);
      expect(next.accepted, isTrue);
      expect(next.remainingTokens, 0);
    });
  });
}

class MemoryStorage implements Storage {
  final Map<String, SlidingWindow> _store = {};

  @override
  Future<void> save(SlidingWindow window) async {
    _store[window.id] = window;
  }

  @override
  Future<SlidingWindow?> fetch(String id) async {
    return _store[id];
  }
}
