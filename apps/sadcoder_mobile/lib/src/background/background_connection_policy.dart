import 'dart:async';

import 'package:flutter/widgets.dart';

class BackgroundConnectionPreferences extends ChangeNotifier {
  BackgroundConnectionPreferences({bool keepConnectionDuringActiveTurn = true})
    : _keepConnectionDuringActiveTurn = keepConnectionDuringActiveTurn;

  bool _keepConnectionDuringActiveTurn;

  bool get keepConnectionDuringActiveTurn => _keepConnectionDuringActiveTurn;

  void setKeepConnectionDuringActiveTurn(bool value) {
    if (value == _keepConnectionDuringActiveTurn) {
      return;
    }
    _keepConnectionDuringActiveTurn = value;
    notifyListeners();
  }
}

class BackgroundConnectionContext {
  const BackgroundConnectionContext({
    this.profileId,
    this.endpoint,
    this.threadId,
    this.turnId,
  });

  final String? profileId;
  final String? endpoint;
  final String? threadId;
  final String? turnId;
}

abstract interface class BackgroundConnectionKeeper {
  Future<BackgroundConnectionRetention> retain(
    BackgroundConnectionContext context,
  );
}

abstract interface class BackgroundConnectionRetention {
  Future<void> release();
}

class BackgroundConnectionUnsupportedException implements Exception {
  const BackgroundConnectionUnsupportedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NoopBackgroundConnectionKeeper implements BackgroundConnectionKeeper {
  const NoopBackgroundConnectionKeeper();

  @override
  Future<BackgroundConnectionRetention> retain(
    BackgroundConnectionContext context,
  ) async {
    return const NoopBackgroundConnectionRetention();
  }
}

class NoopBackgroundConnectionRetention
    implements BackgroundConnectionRetention {
  const NoopBackgroundConnectionRetention();

  @override
  Future<void> release() async {}
}

typedef BackgroundBoolProvider = bool Function();
typedef BackgroundStringProvider = String? Function();
typedef BackgroundDisconnectAction = Future<void> Function();
typedef BackgroundResumeAction = Future<void> Function();

class AppLifecycleConnectionCoordinator {
  AppLifecycleConnectionCoordinator({
    required Listenable sessionListenable,
    required Listenable turnListenable,
    required BackgroundConnectionPreferences preferences,
    required BackgroundBoolProvider isConnected,
    required BackgroundBoolProvider hasActiveTurn,
    required BackgroundStringProvider profileIdProvider,
    required BackgroundStringProvider endpointProvider,
    required BackgroundStringProvider activeThreadIdProvider,
    required BackgroundStringProvider activeTurnIdProvider,
    required BackgroundDisconnectAction disconnect,
    required BackgroundResumeAction resume,
    BackgroundConnectionKeeper keeper = const NoopBackgroundConnectionKeeper(),
  }) : _sessionListenable = sessionListenable,
       _turnListenable = turnListenable,
       _preferences = preferences,
       _isConnected = isConnected,
       _hasActiveTurn = hasActiveTurn,
       _profileIdProvider = profileIdProvider,
       _endpointProvider = endpointProvider,
       _activeThreadIdProvider = activeThreadIdProvider,
       _activeTurnIdProvider = activeTurnIdProvider,
       _disconnect = disconnect,
       _resume = resume,
       _keeper = keeper;

  final Listenable _sessionListenable;
  final Listenable _turnListenable;
  final BackgroundConnectionPreferences _preferences;
  final BackgroundBoolProvider _isConnected;
  final BackgroundBoolProvider _hasActiveTurn;
  final BackgroundStringProvider _profileIdProvider;
  final BackgroundStringProvider _endpointProvider;
  final BackgroundStringProvider _activeThreadIdProvider;
  final BackgroundStringProvider _activeTurnIdProvider;
  final BackgroundDisconnectAction _disconnect;
  final BackgroundResumeAction _resume;
  final BackgroundConnectionKeeper _keeper;

  bool _started = false;
  bool _backgrounded = false;
  bool _disconnecting = false;
  bool _disconnectedForBackground = false;
  Future<void> _pendingOperation = Future<void>.value();
  BackgroundConnectionRetention? _retention;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _sessionListenable.addListener(_handleObservedStateChanged);
    _turnListenable.addListener(_handleObservedStateChanged);
    _preferences.addListener(_handleObservedStateChanged);
  }

  Future<void> dispose() async {
    if (!_started) {
      await _releaseRetention();
      return;
    }
    _started = false;
    _sessionListenable.removeListener(_handleObservedStateChanged);
    _turnListenable.removeListener(_handleObservedStateChanged);
    _preferences.removeListener(_handleObservedStateChanged);
    await _pendingOperation;
    await _releaseRetention();
  }

  Future<void> handleLifecycleState(AppLifecycleState state) {
    return _enqueue(() => _applyLifecycleState(state));
  }

  Future<void> _applyLifecycleState(AppLifecycleState state) async {
    if (_isBackgroundState(state)) {
      _backgrounded = true;
      await _applyBackgroundPolicy();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _backgrounded = false;
      await _releaseRetention();
      await _resumeIfNeeded();
    }
  }

  void _handleObservedStateChanged() {
    if (!_backgrounded) {
      return;
    }
    unawaited(_enqueue(_applyBackgroundPolicy));
  }

  Future<void> _applyBackgroundPolicy() async {
    if (!_isConnected()) {
      await _releaseRetention();
      return;
    }

    final shouldRetain =
        _hasActiveTurn() && _preferences.keepConnectionDuringActiveTurn;
    if (shouldRetain) {
      if (_retention != null) {
        return;
      }
      try {
        _retention = await _keeper.retain(
          BackgroundConnectionContext(
            profileId: _profileIdProvider(),
            endpoint: _endpointProvider(),
            threadId: _activeThreadIdProvider(),
            turnId: _activeTurnIdProvider(),
          ),
        );
      } on Object {
        _retention = null;
        await _disconnectIfNeeded();
      }
      return;
    }

    await _releaseRetention();
    await _disconnectIfNeeded();
  }

  Future<void> _disconnectIfNeeded() async {
    if (_disconnecting || !_isConnected()) {
      return;
    }
    _disconnecting = true;
    _disconnectedForBackground = true;
    try {
      await _disconnect();
    } finally {
      _disconnecting = false;
    }
  }

  Future<void> _resumeIfNeeded() async {
    if (!_disconnectedForBackground) {
      return;
    }
    try {
      await _resume();
      _disconnectedForBackground = false;
    } on Object {
      // Keep the marker so a later foreground transition can retry.
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _pendingOperation.then((_) => operation());
    _pendingOperation = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> _releaseRetention() async {
    final retention = _retention;
    if (retention == null) {
      return;
    }
    _retention = null;
    await retention.release();
  }
}

bool _isBackgroundState(AppLifecycleState state) {
  return switch (state) {
    AppLifecycleState.paused ||
    AppLifecycleState.hidden ||
    AppLifecycleState.detached => true,
    AppLifecycleState.resumed || AppLifecycleState.inactive => false,
  };
}
