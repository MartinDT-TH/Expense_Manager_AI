import 'dart:async';

/// A utility class for debouncing function calls
/// 
/// Usage:
/// ```dart
/// final debouncer = Debouncer(delay: Duration(milliseconds: 500));
/// debouncer.run(() {
///   // This will only execute after 500ms of inactivity
///   print('Debounced!');
/// });
/// ```
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Run the action after the delay
  /// If called again before the delay, the previous call is cancelled
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel any pending action
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose of the debouncer
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// A throttler that limits how often a function can be called
/// 
/// Unlike debouncer, throttler executes the first call immediately
/// and ignores subsequent calls until the delay has passed
class Throttler {
  final Duration delay;
  DateTime? _lastExecutionTime;

  Throttler({this.delay = const Duration(milliseconds: 300)});

  /// Run the action if enough time has passed since the last execution
  void run(void Function() action) {
    final now = DateTime.now();
    if (_lastExecutionTime == null || 
        now.difference(_lastExecutionTime!) >= delay) {
      _lastExecutionTime = now;
      action();
    }
  }

  /// Reset the throttler
  void reset() {
    _lastExecutionTime = null;
  }
}
