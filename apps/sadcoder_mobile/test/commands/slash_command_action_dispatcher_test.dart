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

  test('/status awaits asynchronous status summaries', () async {
    final dispatcher = SlashCommandActionDispatcher(
      showStatus: () async => 'Remote status',
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/status'),
      hasActiveTurn: true,
    );

    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.message, 'Remote status');
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

  test('/usage returns the injected usage summary', () async {
    final dispatcher = SlashCommandActionDispatcher(
      showUsage: () async => 'Usage\nToken usage: Lifetime tokens=1234 tokens',
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/usage'),
      hasActiveTurn: true,
    );

    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.usage);
    expect(result.message, 'Usage\nToken usage: Lifetime tokens=1234 tokens');
  });

  test('/mcp passes inline arguments to the injected status summary', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      showMcp: (argument) async {
        arguments.add(argument);
        return 'MCP servers\nfilesystem: auth: unsupported, tools: 1';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/mcp verbose'),
      hasActiveTurn: true,
    );

    expect(arguments, ['verbose']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.mcp);
    expect(result.message, contains('filesystem'));
  });

  test('/mcp is unavailable when arguments are not supported', () async {
    final dispatcher = SlashCommandActionDispatcher(showMcp: (_) => null);

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/mcp sideways'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'mcp');
  });

  test(
    '/skills passes inline arguments to the injected skill summary',
    () async {
      final arguments = <String>[];
      final dispatcher = SlashCommandActionDispatcher(
        showSkills: (argument) async {
          arguments.add(argument);
          return 'Skills\nPR Babysitter (pr-review): enabled, scope: repo';
        },
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/skills reload'),
        hasActiveTurn: true,
      );

      expect(arguments, ['reload']);
      expect(result.outcome, SlashCommandActionOutcome.executed);
      expect(result.effect, SlashCommandActionEffect.skills);
      expect(result.message, contains('PR Babysitter'));
    },
  );

  test('/skills is unavailable when arguments are not supported', () async {
    final dispatcher = SlashCommandActionDispatcher(showSkills: (_) => null);

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/skills sideways'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'skills');
  });

  test('/plugins returns the injected plugin summary', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      showPlugins: (argument) async {
        arguments.add(argument);
        return 'Plugins\nOpenAI curated\nlinear: installed, enabled';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/plugins'),
      hasActiveTurn: true,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.plugins);
    expect(result.message, contains('linear'));
  });

  test('/plugins is unavailable when arguments are not supported', () async {
    final dispatcher = SlashCommandActionDispatcher(showPlugins: (_) => null);

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/plugins sideways'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'plugins');
  });

  test('/hooks returns the injected hook summary', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      showHooks: (argument) async {
        arguments.add(argument);
        return 'Hooks\npreToolUse: enabled';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/hooks'),
      hasActiveTurn: true,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.hooks);
    expect(result.message, contains('preToolUse'));
  });

  test('/hooks is unavailable when arguments are not supported', () async {
    final dispatcher = SlashCommandActionDispatcher(showHooks: (_) => null);

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/hooks sideways'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'hooks');
  });

  test('/apps returns the injected app summary', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      showApps: (argument) async {
        arguments.add(argument);
        return 'Apps\nLinear: accessible, enabled';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/apps'),
      hasActiveTurn: true,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.apps);
    expect(result.message, contains('Linear'));
  });

  test('/apps is unavailable when arguments are not supported', () async {
    final dispatcher = SlashCommandActionDispatcher(showApps: (_) => null);

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/apps sideways'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'apps');
  });

  test('/goal passes inline arguments to the injected goal handler', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      handleGoal: (argument) async {
        arguments.add(argument);
        return 'Goal\nObjective: Ship goal support';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/goal Ship goal support'),
      hasActiveTurn: true,
    );

    expect(arguments, ['Ship goal support']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.goal);
    expect(result.message, contains('Ship goal support'));
  });

  test('/goal is unavailable when arguments are not supported', () async {
    final dispatcher = SlashCommandActionDispatcher(handleGoal: (_) => null);

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/goal status sideways'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'goal');
  });

  test(
    '/review passes inline arguments to the injected review handler',
    () async {
      final arguments = <String>[];
      final dispatcher = SlashCommandActionDispatcher(
        handleReview: (argument) async {
          arguments.add(argument);
          return 'Review started.\nTarget: current changes';
        },
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/review detached commit abc123'),
        hasActiveTurn: false,
      );

      expect(arguments, ['detached commit abc123']);
      expect(result.outcome, SlashCommandActionOutcome.executed);
      expect(result.effect, SlashCommandActionEffect.review);
      expect(result.message, contains('Review started'));
    },
  );

  test('/review is unavailable when arguments are not supported', () async {
    final dispatcher = SlashCommandActionDispatcher(handleReview: (_) => null);

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/review commit'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'review');
  });

  test('/ps lists background terminals during an active turn', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      showBackgroundTerminals: (argument) {
        arguments.add(argument);
        return 'Background terminals\nNo background terminals running.';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/ps'),
      hasActiveTurn: true,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.backgroundTerminals);
    expect(result.message, contains('Background terminals'));
  });

  test('/stop cleans background terminals during an active turn', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      cleanBackgroundTerminals: (argument) {
        arguments.add(argument);
        return 'Stopping all background terminals.';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/stop'),
      hasActiveTurn: true,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.backgroundTerminalCleanup);
  });

  test('/clean aliases to /stop background terminal cleanup', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      cleanBackgroundTerminals: (_) {
        calls++;
        return 'Stopping all background terminals.';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/clean'),
      hasActiveTurn: true,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.command?.command, 'stop');
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

  test('/fork runs the injected fork action', () async {
    var forks = 0;
    final dispatcher = SlashCommandActionDispatcher(
      forkThread: () async {
        forks++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/fork'),
      hasActiveTurn: false,
    );

    expect(forks, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.forkThread);
  });

  test('/compact runs the injected compaction action', () async {
    var compactions = 0;
    final dispatcher = SlashCommandActionDispatcher(
      compactThread: () async {
        compactions++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/compact'),
      hasActiveTurn: false,
    );

    expect(compactions, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.compactThread);
  });

  test(
    'thread lifecycle commands are unavailable during an active turn',
    () async {
      var forkCalls = 0;
      var compactCalls = 0;
      var archiveCalls = 0;
      var deleteCalls = 0;
      final dispatcher = SlashCommandActionDispatcher(
        forkThread: () async {
          forkCalls++;
          return SlashCommandCallbackResult.executed;
        },
        compactThread: () async {
          compactCalls++;
          return SlashCommandCallbackResult.executed;
        },
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
      final fork = await dispatcher.dispatch(
        registry.parseComposerText('/fork'),
        hasActiveTurn: true,
      );
      final compact = await dispatcher.dispatch(
        registry.parseComposerText('/compact'),
        hasActiveTurn: true,
      );

      expect(archive.outcome, SlashCommandActionOutcome.unavailable);
      expect(delete.outcome, SlashCommandActionOutcome.unavailable);
      expect(fork.outcome, SlashCommandActionOutcome.unavailable);
      expect(compact.outcome, SlashCommandActionOutcome.unavailable);
      expect(forkCalls, 0);
      expect(compactCalls, 0);
      expect(archiveCalls, 0);
      expect(deleteCalls, 0);
    },
  );

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
    '/personality opens the injected personality configuration action',
    () async {
      var opens = 0;
      final dispatcher = SlashCommandActionDispatcher(
        configurePersonality: () async {
          opens++;
          return SlashCommandCallbackResult.executed;
        },
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/personality'),
        hasActiveTurn: true,
      );

      expect(opens, 1);
      expect(result.outcome, SlashCommandActionOutcome.executed);
      expect(result.effect, SlashCommandActionEffect.personalityOverride);
    },
  );

  test('/personality can be cancelled by the configuration UI', () async {
    final dispatcher = SlashCommandActionDispatcher(
      configurePersonality: () async => SlashCommandCallbackResult.cancelled,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/personality'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.cancelled);
    expect(result.command?.command, 'personality');
  });

  test(
    '/permissions opens the injected permissions configuration action',
    () async {
      var opens = 0;
      final dispatcher = SlashCommandActionDispatcher(
        configurePermissions: () async {
          opens++;
          return SlashCommandCallbackResult.executed;
        },
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/permissions'),
        hasActiveTurn: true,
      );

      expect(opens, 1);
      expect(result.outcome, SlashCommandActionOutcome.executed);
      expect(result.effect, SlashCommandActionEffect.permissionsOverride);
    },
  );

  test('/permissions can be cancelled by the configuration UI', () async {
    final dispatcher = SlashCommandActionDispatcher(
      configurePermissions: () async => SlashCommandCallbackResult.cancelled,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/permissions'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.cancelled);
    expect(result.command?.command, 'permissions');
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
        registry.parseComposerText('/keymap'),
        hasActiveTurn: false,
      );

      expect(unknown.outcome, SlashCommandActionOutcome.unknown);
      expect(unknown.rawCommand, 'does-not-exist');
      expect(unsupported.outcome, SlashCommandActionOutcome.unsupported);
      expect(unsupported.command?.command, 'keymap');
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
