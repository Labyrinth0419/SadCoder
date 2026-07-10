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
}

class _Fixture {
  _Fixture({
    String? activeTurnId,
    BackgroundConnectionPreferences? preferences,
    BackgroundConnectionKeeper? keeper,
  }) : preferences = preferences ?? BackgroundConnectionPreferences(),
       keeper = keeper ?? _RecordingKeeper(),
       turnId = ValueNotifier<String?>(activeTurnId) {
    coordinator = AppLifecycleConnectionCoordinator(
      sessionListenable: connected,
      turnListenable: turnId,
      preferences: this.preferences,
      keeper: this.keeper,
      isConnected: () => connected.value,
      hasActiveTurn: () => turnId.value != null,
      profileIdProvider: () => 'local',
      endpointProvider: () => 'tester@localhost:22',
      activeThreadIdProvider: () => turnId.value == null ? null : 'thr_1',
      activeTurnIdProvider: () => turnId.value,
      disconnect: () async {
        disconnects++;
        connected.value = false;
      },
    )..start();
  }

  final ValueNotifier<bool> connected = ValueNotifier<bool>(true);
  final ValueNotifier<String?> turnId;
  final BackgroundConnectionPreferences preferences;
  final BackgroundConnectionKeeper keeper;
  late final AppLifecycleConnectionCoordinator coordinator;
  int disconnects = 0;

  _RecordingKeeper get recordingKeeper => keeper as _RecordingKeeper;

  Future<void> dispose() async {
    await coordinator.dispose();
    connected.dispose();
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
