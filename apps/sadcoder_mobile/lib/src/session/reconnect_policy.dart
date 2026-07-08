import 'dart:async';
import 'dart:math';

abstract interface class ReconnectDelayScheduler {
  Future<void> wait(Duration delay);
}

class TimerReconnectDelayScheduler implements ReconnectDelayScheduler {
  const TimerReconnectDelayScheduler();

  @override
  Future<void> wait(Duration delay) => Future<void>.delayed(delay);
}

class ReconnectPolicy {
  ReconnectPolicy({
    this.delays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
    this.jitterRatio = 0.2,
    Random? random,
  }) : _random = random ?? Random();

  const ReconnectPolicy.fixed({
    this.delays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
  }) : jitterRatio = 0,
       _random = null;

  final List<Duration> delays;
  final double jitterRatio;
  final Random? _random;

  Duration delayForAttempt(int attempt) {
    if (attempt < 1) {
      throw ArgumentError.value(attempt, 'attempt', 'must be >= 1');
    }
    if (delays.isEmpty) {
      throw ArgumentError.value(delays, 'delays', 'must not be empty');
    }

    final base = delays[min(attempt - 1, delays.length - 1)];
    final random = _random;
    if (jitterRatio <= 0 || random == null) {
      return base;
    }

    final jitterWindow = base.inMilliseconds * jitterRatio;
    final offset = ((random.nextDouble() * 2) - 1) * jitterWindow;
    final jitteredMilliseconds = base.inMilliseconds + offset.round();
    return Duration(milliseconds: max(0, jitteredMilliseconds));
  }
}
