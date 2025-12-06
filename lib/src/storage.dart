import 'package:sliding_window_limiter/src/sliding_window.dart';

/// Contract for persisting and retrieving sliding window state.
///
/// Implement this interface to back the limiter with a storage layer
/// such as Redis, a database, in‑memory cache, etc.
abstract class Storage {
  /// Persist the given [window]. Called after each `consume` attempt.
  ///
  /// [ttl] Time-to-live duration for the window storage.
  Future<void> save(SlidingWindow window, Duration ttl);

  /// Retrieve a window by [id]. Returns `null` if no state exists yet.
  Future<SlidingWindow?> fetch(String id);
}
