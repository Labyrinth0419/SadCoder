import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_action_dispatcher.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_registry.dart';

void main() {
  const registry = SlashCommandRegistry();

  test('quit and exit disconnect only through the injected callback', () async {
    var disconnects = 0;
    final dispatcher = SlashCommandActionDispatcher(
      disconnect: () async => disconnects++,
    );

    final quit = await dispatcher.dispatch(
      registry.parseComposerText('/quit'),
      hasActiveTurn: true,
    );
    final exit = await dispatcher.dispatch(
      registry.parseComposerText('/exit'),
      hasActiveTurn: true,
    );

    expect(disconnects, 2);
    expect(quit.outcome, SlashCommandActionOutcome.executed);
    expect(quit.effect, SlashCommandActionEffect.disconnect);
    expect(exit.outcome, SlashCommandActionOutcome.executed);
    expect(exit.effect, SlashCommandActionEffect.disconnect);
  });

  test(
    'clear clears only local transcript state when no turn is active',
    () async {
      var clears = 0;
      final dispatcher = SlashCommandActionDispatcher(
        clearTranscript: () => clears++,
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/clear'),
        hasActiveTurn: false,
      );

      expect(clears, 1);
      expect(result.outcome, SlashCommandActionOutcome.executed);
      expect(result.effect, SlashCommandActionEffect.clearTranscript);
    },
  );

  test('clear is unavailable during an active turn', () async {
    var clears = 0;
    final dispatcher = SlashCommandActionDispatcher(
      clearTranscript: () => clears++,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/clear'),
      hasActiveTurn: true,
    );

    expect(clears, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'clear');
  });

  test('/copy delegates to the injected clipboard action', () async {
    var copies = 0;
    final dispatcher = SlashCommandActionDispatcher(
      copyLastResponse: () async {
        copies++;
        return true;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/copy'),
      hasActiveTurn: true,
    );

    expect(copies, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.copy);
  });

  test('/copy is unavailable when there is no response to copy', () async {
    final dispatcher = SlashCommandActionDispatcher(
      copyLastResponse: () async => false,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/copy'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'copy');
  });

  test('/status returns the injected status summary', () async {
    final dispatcher = SlashCommandActionDispatcher(
      showStatus: () => 'Connected\nThread: thr_1',
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/status'),
      hasActiveTurn: true,
    );

    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.status);
    expect(result.message, 'Connected\nThread: thr_1');
  });

  test('/status is unavailable when no status summary can be built', () async {
    final dispatcher = SlashCommandActionDispatcher(showStatus: () => '  ');

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/status'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'status');
  });

  test('/raw delegates to the injected raw transcript toggle', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      toggleRawTranscript: (argument) {
        arguments.add(argument);
        return true;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/raw on'),
      hasActiveTurn: true,
    );

    expect(arguments, ['on']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.rawTranscript);
  });

  test('/raw is unavailable for unsupported arguments', () async {
    final dispatcher = SlashCommandActionDispatcher(
      toggleRawTranscript: (_) => null,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/raw sideways'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'raw');
  });

  test('/new starts a thread through the injected callback', () async {
    var starts = 0;
    final dispatcher = SlashCommandActionDispatcher(
      startNewThread: () async {
        starts++;
        return true;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/new'),
      hasActiveTurn: false,
    );

    expect(starts, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.newThread);
  });

  test('/new is unavailable when a new thread cannot be started', () async {
    final dispatcher = SlashCommandActionDispatcher(
      startNewThread: () async => false,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/new'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'new');
  });

  test(
    '/resume resumes the requested thread through the injected callback',
    () async {
      final resumedThreads = <String>[];
      final dispatcher = SlashCommandActionDispatcher(
        resumeThread: (threadId) async {
          resumedThreads.add(threadId);
          return true;
        },
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/resume thr_1 '),
        hasActiveTurn: false,
      );

      expect(resumedThreads, ['thr_1']);
      expect(result.outcome, SlashCommandActionOutcome.executed);
      expect(result.effect, SlashCommandActionEffect.resumeThread);
    },
  );

  test('/resume requires an inline thread id', () async {
    final dispatcher = SlashCommandActionDispatcher(
      resumeThread: (_) async => true,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/resume'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'resume');
  });

  test(
    '/rename renames the current thread through the injected callback',
    () async {
      final names = <String>[];
      final dispatcher = SlashCommandActionDispatcher(
        renameThread: (name) async {
          names.add(name);
          return true;
        },
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/rename  Release prep  '),
        hasActiveTurn: true,
      );

      expect(names, ['Release prep']);
      expect(result.outcome, SlashCommandActionOutcome.executed);
      expect(result.effect, SlashCommandActionEffect.renameThread);
    },
  );

  test('/rename requires a non-empty name', () async {
    final dispatcher = SlashCommandActionDispatcher(
      renameThread: (_) async => true,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/rename   '),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'rename');
  });

  test('/archive runs a confirmed thread action', () async {
    var archives = 0;
    final dispatcher = SlashCommandActionDispatcher(
      archiveThread: () async {
        archives++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/archive'),
      hasActiveTurn: false,
    );

    expect(archives, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.archiveThread);
  });

  test('/delete can be cancelled by its confirmation callback', () async {
    final dispatcher = SlashCommandActionDispatcher(
      deleteThread: () async => SlashCommandCallbackResult.cancelled,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/delete'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.cancelled);
    expect(result.command?.command, 'delete');
  });

  test('archive and delete are unavailable during an active turn', () async {
    var archiveCalls = 0;
    var deleteCalls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      archiveThread: () async {
        archiveCalls++;
        return SlashCommandCallbackResult.executed;
      },
      deleteThread: () async {
        deleteCalls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final archive = await dispatcher.dispatch(
      registry.parseComposerText('/archive'),
      hasActiveTurn: true,
    );
    final delete = await dispatcher.dispatch(
      registry.parseComposerText('/delete'),
      hasActiveTurn: true,
    );

    expect(archive.outcome, SlashCommandActionOutcome.unavailable);
    expect(delete.outcome, SlashCommandActionOutcome.unavailable);
    expect(archiveCalls, 0);
    expect(deleteCalls, 0);
  });

  test('/model opens the injected model configuration action', () async {
    var opens = 0;
    final dispatcher = SlashCommandActionDispatcher(
      configureModel: () async {
        opens++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/model'),
      hasActiveTurn: true,
    );

    expect(opens, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.modelOverride);
  });

  test('/model can be cancelled by the configuration UI', () async {
    final dispatcher = SlashCommandActionDispatcher(
      configureModel: () async => SlashCommandCallbackResult.cancelled,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/model'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.cancelled);
    expect(result.command?.command, 'model');
  });

  test(
    'unknown and unsupported commands never fall through as prompts',
    () async {
      final dispatcher = SlashCommandActionDispatcher(
        disconnect: () async {},
        clearTranscript: () {},
      );

      final unknown = await dispatcher.dispatch(
        registry.parseComposerText('/does-not-exist now'),
        hasActiveTurn: false,
      );
      final unsupported = await dispatcher.dispatch(
        registry.parseComposerText('/permissions'),
        hasActiveTurn: false,
      );

      expect(unknown.outcome, SlashCommandActionOutcome.unknown);
      expect(unknown.rawCommand, 'does-not-exist');
      expect(unsupported.outcome, SlashCommandActionOutcome.unsupported);
      expect(unsupported.command?.command, 'permissions');
    },
  );

  test('callback failures are reported as command failures', () async {
    final dispatcher = SlashCommandActionDispatcher(
      disconnect: () async => throw StateError('disconnect failed'),
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/quit'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.failed);
    expect(result.error, isA<StateError>());
  });
}
