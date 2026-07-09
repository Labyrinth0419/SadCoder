import 'package:flutter/foundation.dart';

import '../config/codex_config_overrides.dart';
import '../threads/thread_summary.dart';
import 'turn_runner.dart';

typedef TurnRunnerProvider = TurnRunner? Function();
typedef ActiveThreadIdProvider = String? Function();

enum TurnControllerStatus {
  idle,
  startingThread,
  resumingThread,
  sendingTurn,
  submitted,
  completed,
  interrupting,
  interrupted,
  failed,
}

class TurnController extends ChangeNotifier {
  TurnController({
    required TurnRunnerProvider runnerProvider,
    ActiveThreadIdProvider? activeThreadIdProvider,
    CodexConfigOverrideLayersProvider? overrideLayersProvider,
  }) : _runnerProvider = runnerProvider,
       _activeThreadIdProvider = activeThreadIdProvider,
       _overrideLayersProvider = overrideLayersProvider;

  final TurnRunnerProvider _runnerProvider;
  final ActiveThreadIdProvider? _activeThreadIdProvider;
  final CodexConfigOverrideLayersProvider? _overrideLayersProvider;
  TurnControllerStatus _status = TurnControllerStatus.idle;
  Object? _error;
  String? _activeThreadId;
  String? _activeTurnId;
  TurnSummary? _lastTurn;
  int _generation = 0;

  TurnControllerStatus get status => _status;
  Object? get error => _error;
  String? get activeThreadId => _activeThreadId;
  String? get activeTurnId => _activeTurnId;
  TurnSummary? get lastTurn => _lastTurn;

  bool get isBusy => switch (_status) {
    TurnControllerStatus.startingThread ||
    TurnControllerStatus.resumingThread ||
    TurnControllerStatus.sendingTurn ||
    TurnControllerStatus.interrupting => true,
    _ => false,
  };

  bool get canInterrupt =>
      !isBusy && _activeThreadId != null && _activeTurnId != null;

  bool get canSubmit => !isBusy && _activeTurnId == null;

  void finishTurn({required String threadId, required TurnSummary turn}) {
    if (_activeThreadId != threadId || _activeTurnId != turn.id) {
      return;
    }
    _lastTurn = turn;
    _activeTurnId = null;
    if (turn.status == 'failed') {
      _setState(
        status: TurnControllerStatus.failed,
        error: turn.errorMessage ?? StateError('Turn failed'),
      );
      return;
    }
    _setState(
      status: turn.status == 'interrupted'
          ? TurnControllerStatus.interrupted
          : TurnControllerStatus.completed,
      error: null,
    );
  }

  Future<void> submitText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (isBusy) {
      throw StateError('A turn transition is already in progress');
    }
    if (_activeTurnId != null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: StateError('An active turn is already running'),
      );
      return;
    }

    final runner = _runnerProvider();
    if (runner == null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: StateError('No active Codex session'),
      );
      return;
    }

    final generation = ++_generation;
    try {
      var threadId = _activeThreadId;
      final selectedThreadId = _selectedThreadId();
      if (selectedThreadId != null && selectedThreadId != threadId) {
        _setState(status: TurnControllerStatus.resumingThread, error: null);
        final thread = await runner.resumeThread(threadId: selectedThreadId);
        if (generation != _generation) {
          return;
        }
        threadId = thread.id;
      } else if (threadId == null || threadId.isEmpty) {
        _setState(status: TurnControllerStatus.startingThread, error: null);
        final thread = await runner.startThread();
        if (generation != _generation) {
          return;
        }
        threadId = thread.id;
      }
      if (threadId.isEmpty) {
        throw StateError('Codex did not return a thread id');
      }
      _activeThreadId = threadId;
      _setState(status: TurnControllerStatus.sendingTurn, error: null);
      final turn = await runner.startTurn(
        threadId: threadId,
        text: trimmed,
        overrides: _resolvedOverrides(),
      );
      if (generation != _generation) {
        return;
      }
      _lastTurn = turn;
      _activeTurnId = turn.id;
      _setState(status: TurnControllerStatus.submitted, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: TurnControllerStatus.failed, error: error);
    }
  }

  Future<bool> startNewThread() async {
    if (isBusy || _activeTurnId != null) {
      return false;
    }
    final runner = _runnerProvider();
    if (runner == null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: StateError('No active Codex session'),
      );
      return false;
    }

    final generation = ++_generation;
    _setState(status: TurnControllerStatus.startingThread, error: null);
    try {
      final thread = await runner.startThread();
      if (generation != _generation) {
        return false;
      }
      if (thread.id.isEmpty) {
        throw StateError('Codex did not return a thread id');
      }
      _activeThreadId = thread.id;
      _activeTurnId = null;
      _lastTurn = null;
      _setState(status: TurnControllerStatus.idle, error: null);
      return true;
    } on Object catch (error) {
      if (generation != _generation) {
        return false;
      }
      _setState(status: TurnControllerStatus.failed, error: error);
      return false;
    }
  }

  Future<bool> resumeThread(String threadId) async {
    final trimmedThreadId = threadId.trim();
    if (trimmedThreadId.isEmpty || isBusy || _activeTurnId != null) {
      return false;
    }
    final runner = _runnerProvider();
    if (runner == null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: StateError('No active Codex session'),
      );
      return false;
    }

    final generation = ++_generation;
    _setState(status: TurnControllerStatus.resumingThread, error: null);
    try {
      final thread = await runner.resumeThread(threadId: trimmedThreadId);
      if (generation != _generation) {
        return false;
      }
      if (thread.id.isEmpty) {
        throw StateError('Codex did not return a thread id');
      }
      _activeThreadId = thread.id;
      _activeTurnId = null;
      _lastTurn = null;
      _setState(status: TurnControllerStatus.idle, error: null);
      return true;
    } on Object catch (error) {
      if (generation != _generation) {
        return false;
      }
      _setState(status: TurnControllerStatus.failed, error: error);
      return false;
    }
  }

  bool activateThread(String threadId) {
    final trimmedThreadId = threadId.trim();
    if (trimmedThreadId.isEmpty || isBusy || _activeTurnId != null) {
      return false;
    }
    _generation++;
    _activeThreadId = trimmedThreadId;
    _activeTurnId = null;
    _lastTurn = null;
    _setState(status: TurnControllerStatus.idle, error: null);
    return true;
  }

  Future<void> interruptActiveTurn() async {
    if (isBusy) {
      throw StateError('A turn transition is already in progress');
    }
    final threadId = _activeThreadId;
    final turnId = _activeTurnId;
    if (threadId == null || turnId == null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: StateError('No active turn to interrupt'),
      );
      return;
    }
    final runner = _runnerProvider();
    if (runner == null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: StateError('No active Codex session'),
      );
      return;
    }

    final generation = ++_generation;
    _setState(status: TurnControllerStatus.interrupting, error: null);
    try {
      await runner.interruptTurn(threadId: threadId, turnId: turnId);
      if (generation != _generation) {
        return;
      }
      _activeTurnId = null;
      _setState(status: TurnControllerStatus.interrupted, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: TurnControllerStatus.failed, error: error);
    }
  }

  void clearActiveTurn() {
    _generation++;
    _activeTurnId = null;
    _lastTurn = null;
    _setState(status: TurnControllerStatus.idle, error: null);
  }

  void clearLocalConversation() {
    _generation++;
    _activeThreadId = null;
    _activeTurnId = null;
    _lastTurn = null;
    _setState(status: TurnControllerStatus.idle, error: null);
  }

  String? _selectedThreadId() {
    final selectedThreadId = _activeThreadIdProvider?.call();
    if (selectedThreadId != null && selectedThreadId.trim().isNotEmpty) {
      return selectedThreadId;
    }
    return null;
  }

  CodexConfigOverrides _resolvedOverrides() {
    return _overrideLayersProvider?.call().resolve() ??
        CodexConfigOverrides.empty;
  }

  void _setState({required TurnControllerStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
