import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/background/background_connection_policy.dart';

void main() {
  test('background without active turn disconnects observation', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);

    expect(fixture.disconnects, 1);
    expect(fixture.connected.value, false);
    expect(fixture.recordingKeeper.retainContexts, isEmpty);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.resumed);

    expect(fixture.resumes, 1);
    expect(fixture.connected.value, true);
  });

  test('background with active turn retains the connection', () async {
    final fixture = _Fixture(activeTurnId: 'turn_1');
    addTearDown(fixture.dispose);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);

    expect(fixture.disconnects, 0);
    expect(fixture.connected.value, true);
    expect(fixture.recordingKeeper.retainContexts.single.profileId, 'local');
    expect(fixture.recordingKeeper.retainContexts.single.turnId, 'turn_1');

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.resumed);

    expect(fixture.recordingKeeper.retentions.single.released, true);
    expect(fixture.resumes, 0);
  });

  test('background active turn changes refresh retention context', () async {
    final fixture = _Fixture(activeTurnId: 'turn_1');
    addTearDown(fixture.dispose);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);
    fixture.threadId.value = 'thr_2';
    fixture.turnId.value = 'turn_2';
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(fixture.disconnects, 0);
    expect(fixture.connected.value, true);
    expect(
      fixture.recordingKeeper.retainContexts.map((context) => context.turnId),
      ['turn_1', 'turn_2'],
    );
    expect(fixture.recordingKeeper.retainContexts.last.threadId, 'thr_2');
    expect(fixture.recordingKeeper.retentions.first.released, true);
    expect(fixture.recordingKeeper.retentions.last.released, false);
  });

  test('disabled active-turn retention disconnects in background', () async {
    final preferences = BackgroundConnectionPreferences(
      keepConnectionDuringActiveTurn: false,
    );
    final fixture = _Fixture(activeTurnId: 'turn_1', preferences: preferences);
    addTearDown(fixture.dispose);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);

    expect(fixture.disconnects, 1);
    expect(fixture.recordingKeeper.retainContexts, isEmpty);
  });

  test(
    'active turn completion while backgrounded releases and disconnects',
    () async {
      final fixture = _Fixture(activeTurnId: 'turn_1');
      addTearDown(fixture.dispose);

      await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);
      fixture.turnId.value = null;
      await Future<void>.delayed(Duration.zero);

      expect(fixture.recordingKeeper.retentions.single.released, true);
      expect(fixture.disconnects, 1);
      expect(fixture.connected.value, false);
    },
  );

  test(
    'retained connection loss while backgrounded resumes on foreground',
    () async {
      final fixture = _Fixture(activeTurnId: 'turn_1');
      addTearDown(fixture.dispose);

      await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);
      fixture.connected.value = false;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fixture.recordingKeeper.retentions.single.released, true);
      expect(fixture.disconnects, 0);

      await fixture.coordinator.handleLifecycleState(AppLifecycleState.resumed);

      expect(fixture.resumes, 1);
      expect(fixture.connected.value, true);
    },
  );

  test('retention failure disconnects observation', () async {
    final fixture = _Fixture(
      activeTurnId: 'turn_1',
      keeper: const _FailingKeeper(),
    );
    addTearDown(fixture.dispose);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);

    expect(fixture.disconnects, 1);
    expect(fixture.connected.value, false);
  });

  test('unsupported platform retention disconnects observation', () async {
    final fixture = _Fixture(
      activeTurnId: 'turn_1',
      keeper: const _UnsupportedKeeper(),
    );
    addTearDown(fixture.dispose);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);

    expect(fixture.disconnects, 1);
    expect(fixture.connected.value, false);
  });

  test('rapid resume waits for the background disconnect to finish', () async {
    final disconnectGate = Completer<void>();
    final events = <String>[];
    late _Fixture fixture;
    fixture = _Fixture(
      disconnect: () async {
        events.add('disconnect-start');
        await disconnectGate.future;
        fixture.disconnects++;
        fixture.connected.value = false;
        events.add('disconnect-end');
      },
      resume: () async {
        fixture.resumes++;
        fixture.connected.value = true;
        events.add('resume');
      },
    );
    addTearDown(fixture.dispose);

    final paused = fixture.coordinator.handleLifecycleState(
      AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    final resumed = fixture.coordinator.handleLifecycleState(
      AppLifecycleState.resumed,
    );
    await Future<void>.delayed(Duration.zero);

    expect(events, ['disconnect-start']);

    disconnectGate.complete();
    await Future.wait([paused, resumed]);

    expect(events, ['disconnect-start', 'disconnect-end', 'resume']);
    expect(fixture.connected.value, true);
  });
}

class _Fixture {
  _Fixture({
    String? activeTurnId,
    BackgroundConnectionPreferences? preferences,
    BackgroundConnectionKeeper? keeper,
    BackgroundDisconnectAction? disconnect,
    BackgroundResumeAction? resume,
  }) : preferences = preferences ?? BackgroundConnectionPreferences(),
       keeper = keeper ?? _RecordingKeeper(),
       threadId = ValueNotifier<String?>(activeTurnId == null ? null : 'thr_1'),
       turnId = ValueNotifier<String?>(activeTurnId) {
    final disconnectAction =
        disconnect ??
        () async {
          disconnects++;
          connected.value = false;
        };
    final resumeAction =
        resume ??
        () async {
          resumes++;
          connected.value = true;
        };
    coordinator = AppLifecycleConnectionCoordinator(
      sessionListenable: connected,
      turnListenable: turnId,
      preferences: this.preferences,
      keeper: this.keeper,
      isConnected: () => connected.value,
      hasActiveTurn: () => turnId.value != null,
      profileIdProvider: () => 'local',
      profileLabelProvider: () => 'Local workstation',
      endpointProvider: () => 'tester@localhost:22',
      activeThreadIdProvider: () => threadId.value,
      activeTurnIdProvider: () => turnId.value,
      disconnect: disconnectAction,
      resume: resumeAction,
    )..start();
  }

  final ValueNotifier<bool> connected = ValueNotifier<bool>(true);
  final ValueNotifier<String?> threadId;
  final ValueNotifier<String?> turnId;
  final BackgroundConnectionPreferences preferences;
  final BackgroundConnectionKeeper keeper;
  late final AppLifecycleConnectionCoordinator coordinator;
  int disconnects = 0;
  int resumes = 0;

  _RecordingKeeper get recordingKeeper => keeper as _RecordingKeeper;

  Future<void> dispose() async {
    await coordinator.dispose();
    connected.dispose();
    threadId.dispose();
    turnId.dispose();
    preferences.dispose();
  }
}

class _RecordingKeeper implements BackgroundConnectionKeeper {
  final retainContexts = <BackgroundConnectionContext>[];
  final retentions = <_RecordingRetention>[];

  @override
  Future<BackgroundConnectionRetention> retain(
    BackgroundConnectionContext context,
  ) async {
    retainContexts.add(context);
    final retention = _RecordingRetention();
    retentions.add(retention);
    return retention;
  }
}

class _RecordingRetention implements BackgroundConnectionRetention {
  bool released = false;

  @override
  Future<void> release() async {
    released = true;
  }
}

class _FailingKeeper implements BackgroundConnectionKeeper {
  const _FailingKeeper();

  @override
  Future<BackgroundConnectionRetention> retain(
    BackgroundConnectionContext context,
  ) async {
    throw StateError('foreground service unavailable');
  }
}

class _UnsupportedKeeper implements BackgroundConnectionKeeper {
  const _UnsupportedKeeper();

  @override
  Future<BackgroundConnectionRetention> retain(
    BackgroundConnectionContext context,
  ) async {
    throw const BackgroundConnectionUnsupportedException('unsupported');
  }
}
