import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/codex_config_overrides.dart';
import '../threads/thread_summary.dart';
import 'turn_runner.dart';
import 'turn_text_element.dart';

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

enum TurnControllerFailure {
  turnFailed,
  activeTurnAlreadyRunning,
  noActiveCodexSession,
  missingThreadId,
  noActiveTurnToInterrupt,
  transitionInProgress,
}

class TurnControllerException implements Exception {
  const TurnControllerException(this.failure, [this.detail]);

  final TurnControllerFailure failure;
  final Object? detail;

  @override
  String toString() {
    final detail = this.detail;
    if (detail == null) {
      return 'TurnControllerException.${failure.name}';
    }
    return 'TurnControllerException.${failure.name}: $detail';
  }
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
        error:
            turn.errorMessage ??
            const TurnControllerException(TurnControllerFailure.turnFailed),
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

  Future<void> submitText(
    String text, {
    List<TurnTextElement> textElements = const [],
  }) async {
    final submission = _prepareSubmittedText(text, textElements);
    if (submission.text.isEmpty) {
      return;
    }
    if (isBusy) {
      throw const TurnControllerException(
        TurnControllerFailure.transitionInProgress,
      );
    }
    if (_activeTurnId != null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: const TurnControllerException(
          TurnControllerFailure.activeTurnAlreadyRunning,
        ),
      );
      return;
    }

    final runner = _runnerProvider();
    if (runner == null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: const TurnControllerException(
          TurnControllerFailure.noActiveCodexSession,
        ),
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
        throw const TurnControllerException(
          TurnControllerFailure.missingThreadId,
        );
      }
      _activeThreadId = threadId;
      _setState(status: TurnControllerStatus.sendingTurn, error: null);
      final turn = await runner.startTurn(
        threadId: threadId,
        text: submission.text,
        textElements: submission.textElements,
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
        error: const TurnControllerException(
          TurnControllerFailure.noActiveCodexSession,
        ),
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
        throw const TurnControllerException(
          TurnControllerFailure.missingThreadId,
        );
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
        error: const TurnControllerException(
          TurnControllerFailure.noActiveCodexSession,
        ),
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
        throw const TurnControllerException(
          TurnControllerFailure.missingThreadId,
        );
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

  bool restoreCachedActiveThread(String? threadId) {
    final trimmedThreadId = threadId?.trim();
    if (trimmedThreadId == null || trimmedThreadId.isEmpty) {
      return false;
    }
    if (_activeThreadId == trimmedThreadId &&
        _activeTurnId == null &&
        _status == TurnControllerStatus.idle) {
      return false;
    }
    _generation++;
    _activeThreadId = trimmedThreadId;
    _activeTurnId = null;
    _lastTurn = null;
    _setState(status: TurnControllerStatus.idle, error: null);
    return true;
  }

  bool trackStartedTurn({required String threadId, required TurnSummary turn}) {
    final trimmedThreadId = threadId.trim();
    if (trimmedThreadId.isEmpty || turn.id.isEmpty || isBusy) {
      return false;
    }
    if (_activeTurnId != null) {
      return false;
    }
    _generation++;
    _activeThreadId = trimmedThreadId;
    _activeTurnId = turn.id;
    _lastTurn = turn;
    _setState(status: TurnControllerStatus.submitted, error: null);
    return true;
  }

  Future<void> interruptActiveTurn() async {
    if (isBusy) {
      throw const TurnControllerException(
        TurnControllerFailure.transitionInProgress,
      );
    }
    final threadId = _activeThreadId;
    final turnId = _activeTurnId;
    if (threadId == null || turnId == null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: const TurnControllerException(
          TurnControllerFailure.noActiveTurnToInterrupt,
        ),
      );
      return;
    }
    final runner = _runnerProvider();
    if (runner == null) {
      _setState(
        status: TurnControllerStatus.failed,
        error: const TurnControllerException(
          TurnControllerFailure.noActiveCodexSession,
        ),
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

_SubmittedTurnText _prepareSubmittedText(
  String text,
  List<TurnTextElement> textElements,
) {
  final leadingTrimmed = text.length - text.trimLeft().length;
  final trailingTrimmed = text.trimRight().length;
  final trimmed = text.substring(leadingTrimmed, trailingTrimmed);
  if (trimmed.isEmpty || textElements.isEmpty) {
    return _SubmittedTurnText(text: trimmed, textElements: const []);
  }

  final leadingBytes = utf8.encode(text.substring(0, leadingTrimmed)).length;
  final trailingBytes = utf8.encode(text.substring(0, trailingTrimmed)).length;
  final rebased = <TurnTextElement>[
    for (final element in textElements)
      if (element.isValid &&
          element.start >= leadingBytes &&
          element.end <= trailingBytes)
        element.shift(-leadingBytes),
  ];
  return _SubmittedTurnText(text: trimmed, textElements: rebased);
}

class _SubmittedTurnText {
  const _SubmittedTurnText({required this.text, required this.textElements});

  final String text;
  final List<TurnTextElement> textElements;
}
