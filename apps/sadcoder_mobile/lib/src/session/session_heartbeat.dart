import 'dart:async';

import 'codex_session_connector.dart';

abstract interface class SessionHeartbeatRunner {
  Future<void> ping(CodexSessionConnectionHandle connection);
}

class ThreadListSessionHeartbeatRunner implements SessionHeartbeatRunner {
  const ThreadListSessionHeartbeatRunner();

  @override
  Future<void> ping(CodexSessionConnectionHandle connection) async {
    await connection.threadListReader.listThreads(limit: 1);
  }
}

abstract interface class SessionHeartbeatScheduler {
  SessionHeartbeatHandle start({
    required Duration interval,
    required Future<void> Function() tick,
  });
}

abstract interface class SessionHeartbeatHandle {
  void stop();
}

class TimerSessionHeartbeatScheduler implements SessionHeartbeatScheduler {
  const TimerSessionHeartbeatScheduler();

  @override
  SessionHeartbeatHandle start({
    required Duration interval,
    required Future<void> Function() tick,
  }) {
    return _TimerSessionHeartbeatHandle(interval: interval, tick: tick);
  }
}

class _TimerSessionHeartbeatHandle implements SessionHeartbeatHandle {
  _TimerSessionHeartbeatHandle({
    required Duration interval,
    required Future<void> Function() tick,
  }) : _tick = tick {
    _timer = Timer.periodic(interval, (_) => _run());
  }

  final Future<void> Function() _tick;
  Timer? _timer;
  bool _running = false;
  bool _stopped = false;

  Future<void> _run() async {
    if (_running || _stopped) {
      return;
    }
    _running = true;
    try {
      await _tick();
    } finally {
      _running = false;
    }
  }

  @override
  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }
}
