import 'package:sliding_window_limiter/sliding_window_limiter.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    SlidingWindowLimiter getNewLimiter() => SlidingWindowLimiter(
      id: 'client-IP-address-or-user-id',
      limit: 120,
      interval: Duration(minutes: 1),
      storage: MemoryStorage(),
    );

    setUp(() {
      // Additional setup goes here.
    });

    test('Initiation test', () {
      final limiter = getNewLimiter();
      expect(limiter, isNotNull);
      expect(limiter.id, 'client-IP-address-or-user-id');
      expect(limiter.limit, 120);
      expect(limiter.interval, Duration(minutes: 1));
      expect(limiter.storage, isA<MemoryStorage>());
    });

    test('Successfully consume tokens', () async {
      final limiter = getNewLimiter();
      final rateLimit = await limiter.consume(1);
      expect(rateLimit.accepted, isTrue);
      expect(rateLimit.remainingTokens.toInt(), 119);
      expect(rateLimit.limit, 120);
      expect(rateLimit.waitTime.inSeconds, 0);
    });

    test('Consume more than limit', () async {
      final limiter = getNewLimiter();
      await limiter.consume(120);
      final rateLimit = await limiter.consume(1);
      expect(rateLimit.accepted, isFalse);
      expect(rateLimit.remainingTokens.toInt(), 0);
      expect(rateLimit.limit, 120);
      expect(rateLimit.waitTime.inMicroseconds, greaterThan(0));
    });

    test('Consume with wait time', () async {
      final limiter = getNewLimiter();
      await limiter.consume(120);
      await Future.delayed(Duration(seconds: 1));
      final rateLimit = await limiter.consume(2);
      expect(rateLimit.accepted, isTrue);
      expect(rateLimit.waitTime.inMicroseconds, 0);
      expect(rateLimit.remainingTokens, lessThan(1));
    });

    test('Consume more than limit with wait time', () async {
      final limiter = getNewLimiter();
      await limiter.consume(120);
      await Future.delayed(Duration(seconds: 1));
      final rateLimit = await limiter.consume(3);
      expect(rateLimit.accepted, isFalse);
      expect(rateLimit.waitTime.inSeconds, lessThan(1));
      expect(rateLimit.remainingTokens, lessThan(3));
    });
  });
}

class MemoryStorage implements Storage {
  final Map<String, SlidingWindow> _store = {};

  @override
  Future<void> save(SlidingWindow window) async {
    _store[window.id] = window;
    // print('Window saved: ${window.toJson()}');
  }

  @override
  Future<SlidingWindow?> fetch(String id) async {
    final window = _store[id];
    if (window == null || window.isExpired()) {
      return null;
    }
    return window;
  }
}
