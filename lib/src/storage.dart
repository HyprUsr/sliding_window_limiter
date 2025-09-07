import 'package:sliding_window_limiter/src/sliding_window.dart';

abstract class Storage {
  Future<void> save(SlidingWindow window);
  Future<SlidingWindow?> fetch(String id);
}
