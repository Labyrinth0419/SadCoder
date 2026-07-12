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

  test('/import reports the guarded mobile fallback diagnostic', () async {
    const dispatcher = SlashCommandActionDispatcher();

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/import'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.importFlow);
    expect(result.command?.command, 'import');
  });

  test('/import rejects unsupported inline arguments', () async {
    const dispatcher = SlashCommandActionDispatcher();

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/import claude'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'import');
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

  test('/app reports mobile Desktop handoff diagnostic locally', () async {
    const dispatcher = SlashCommandActionDispatcher();

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/app'),
      hasActiveTurn: true,
    );

    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.appHandoff);
    expect(result.command?.command, 'app');
  });

  test('/app rejects unsupported inline arguments', () async {
    const dispatcher = SlashCommandActionDispatcher();

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/app desktop'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'app');
  });

  test('/debug-config returns the injected debug config summary', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      showDebugConfig: (argument) async {
        arguments.add(argument);
        return 'Debug config\nEffective values';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/debug-config'),
      hasActiveTurn: true,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.debugConfig);
    expect(result.message, contains('Effective values'));
  });

  test(
    '/debug-config is unavailable when arguments are not supported',
    () async {
      final dispatcher = SlashCommandActionDispatcher(
        showDebugConfig: (_) => null,
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/debug-config sideways'),
        hasActiveTurn: false,
      );

      expect(result.outcome, SlashCommandActionOutcome.unavailable);
      expect(result.command?.command, 'debug-config');
    },
  );

  test('/experimental returns the injected experimental summary', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      showExperimental: (argument) {
        arguments.add(argument);
        return 'Experimental features\nApp-server experimental API: enabled';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/experimental'),
      hasActiveTurn: false,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.experimental);
    expect(result.message, contains('App-server experimental API'));
  });

  test('/experimental rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      showExperimental: (arguments) {
        calls++;
        return arguments.trim().isEmpty ? 'Experimental features' : null;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/experimental enable'),
      hasActiveTurn: false,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'experimental');
  });

  test('/experimental is unavailable during an active turn', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      showExperimental: (_) {
        calls++;
        return 'Experimental features';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/experimental'),
      hasActiveTurn: true,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'experimental');
  });

  test('/memories returns the injected memory summary', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      showMemories: (argument) {
        arguments.add(argument);
        return 'Memories\nThread memory mode: disabled';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/memories'),
      hasActiveTurn: false,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.memories);
    expect(result.message, contains('Thread memory mode'));
  });

  test('/memories rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      showMemories: (arguments) {
        calls++;
        return arguments.trim().isEmpty ? 'Memories' : null;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/memories reset'),
      hasActiveTurn: false,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'memories');
  });

  test('/memories is unavailable during an active turn', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      showMemories: (_) {
        calls++;
        return 'Memories';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/memories'),
      hasActiveTurn: true,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'memories');
  });

  test('/rollout returns the injected rollout summary', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      showRollout: (argument) {
        arguments.add(argument);
        return 'Rollout path is not available yet.';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/rollout'),
      hasActiveTurn: true,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.rollout);
    expect(result.message, 'Rollout path is not available yet.');
  });

  test('/rollout is unavailable when arguments are not supported', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      showRollout: (arguments) {
        calls++;
        return arguments.trim().isEmpty
            ? 'Rollout path is not available yet.'
            : null;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/rollout extra'),
      hasActiveTurn: false,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'rollout');
  });

  test('/test-approval queues the injected approval request', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      testApproval: (argument) {
        arguments.add(argument);
        return 'Test approval request queued.';
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/test-approval'),
      hasActiveTurn: true,
    );

    expect(arguments, ['']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.testApproval);
    expect(result.message, 'Test approval request queued.');
  });

  test('/test-approval rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      testApproval: (arguments) {
        calls++;
        return arguments.trim().isEmpty
            ? 'Test approval request queued.'
            : null;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/test-approval extra'),
      hasActiveTurn: false,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'test-approval');
  });

  test('/diff returns the injected diff summary', () async {
    final dispatcher = SlashCommandActionDispatcher(
      showDiff: (_) => 'diff --git a/lib/main.dart b/lib/main.dart',
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/diff'),
      hasActiveTurn: true,
    );

    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.diff);
    expect(result.message, contains('diff --git'));
  });

  test('/diff is unavailable when arguments are not supported', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      showDiff: (arguments) {
        calls++;
        return arguments.trim().isEmpty ? 'diff' : null;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/diff --cached'),
      hasActiveTurn: false,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'diff');
  });

  test('/mention runs the injected file picker action', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      mentionFile: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/mention'),
      hasActiveTurn: false,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.mention);
  });

  test('/mention rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      mentionFile: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/mention lib/main.dart'),
      hasActiveTurn: false,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'mention');
  });

  test('/logout runs the injected confirmed account action', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      logout: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/logout'),
      hasActiveTurn: false,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.logout);
  });

  test('/logout rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      logout: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/logout all'),
      hasActiveTurn: false,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'logout');
  });

  test('/feedback runs the injected feedback action', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      submitFeedback: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/feedback'),
      hasActiveTurn: true,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.feedback);
  });

  test('/feedback rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      submitFeedback: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/feedback now'),
      hasActiveTurn: false,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'feedback');
  });

  test('/theme runs the injected theme action', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      configureTheme: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/theme'),
      hasActiveTurn: false,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.theme);
  });

  test('/theme rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      configureTheme: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/theme dark'),
      hasActiveTurn: false,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'theme');
  });

  test('/title runs the injected title display action', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      configureTitleDisplay: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/title'),
      hasActiveTurn: true,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.titleDisplay);
  });

  test('/title rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      configureTitleDisplay: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/title thread'),
      hasActiveTurn: false,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'title');
  });

  test('/statusline runs the injected status line display action', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      configureStatusLineDisplay: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/statusline'),
      hasActiveTurn: true,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.statusLineDisplay);
  });

  test('/statusline rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      configureStatusLineDisplay: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/statusline model'),
      hasActiveTurn: false,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'statusline');
  });

  test('/ide passes inline arguments to the injected context action', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      attachIdeContext: (argument) async {
        arguments.add(argument);
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/ide main.dart'),
      hasActiveTurn: true,
    );

    expect(arguments, ['main.dart']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.ideContext);
  });

  test('/ide reports unavailable arguments from the injected action', () async {
    final dispatcher = SlashCommandActionDispatcher(
      attachIdeContext: (_) async => SlashCommandCallbackResult.unavailable,
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/ide missing'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'ide');
  });

  test('/plan passes inline arguments to the injected mode action', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      configurePlanMode: (argument) async {
        arguments.add(argument);
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/plan outline the work'),
      hasActiveTurn: false,
    );

    expect(arguments, ['outline the work']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.planMode);
  });

  test('/plan is unavailable during an active turn', () async {
    var called = false;
    final dispatcher = SlashCommandActionDispatcher(
      configurePlanMode: (_) async {
        called = true;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/plan'),
      hasActiveTurn: true,
    );

    expect(called, isFalse);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'plan');
  });

  test(
    '/keymap passes inline arguments to the injected keymap action',
    () async {
      final arguments = <String>[];
      final dispatcher = SlashCommandActionDispatcher(
        configureKeymap: (argument) async {
          arguments.add(argument);
          return SlashCommandCallbackResult.executed;
        },
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/keymap ctrl-enter'),
        hasActiveTurn: false,
      );

      expect(arguments, ['ctrl-enter']);
      expect(result.outcome, SlashCommandActionOutcome.executed);
      expect(result.effect, SlashCommandActionEffect.keymap);
    },
  );

  test(
    '/keymap reports unavailable arguments from the injected action',
    () async {
      final dispatcher = SlashCommandActionDispatcher(
        configureKeymap: (_) async => SlashCommandCallbackResult.unavailable,
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/keymap space'),
        hasActiveTurn: false,
      );

      expect(result.outcome, SlashCommandActionOutcome.unavailable);
      expect(result.command?.command, 'keymap');
    },
  );

  test('/keymap is unavailable during an active turn', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      configureKeymap: (_) async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/keymap ctrl-enter'),
      hasActiveTurn: true,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'keymap');
  });

  test('/vim toggles the injected composer mode action', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      toggleComposerVimMode: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/vim'),
      hasActiveTurn: false,
    );

    expect(calls, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.composerVimMode);
  });

  test('/vim rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      toggleComposerVimMode: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/vim on'),
      hasActiveTurn: false,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'vim');
  });

  test('/vim is unavailable during an active turn', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      toggleComposerVimMode: () async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/vim'),
      hasActiveTurn: true,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'vim');
  });

  test('/pets passes inline arguments to the injected pet action', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      configureTerminalPets: (argument) async {
        arguments.add(argument);
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/pets hide'),
      hasActiveTurn: false,
    );

    expect(arguments, ['hide']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.terminalPets);
  });

  test('/pet alias routes to the terminal pet action', () async {
    final arguments = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      configureTerminalPets: (argument) async {
        arguments.add(argument);
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/pet show'),
      hasActiveTurn: false,
    );

    expect(arguments, ['show']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.command?.command, 'pets');
    expect(result.rawCommand, 'pet');
  });

  test(
    '/pets reports unavailable arguments from the injected action',
    () async {
      final dispatcher = SlashCommandActionDispatcher(
        configureTerminalPets: (_) async =>
            SlashCommandCallbackResult.unavailable,
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/pets dragon'),
        hasActiveTurn: false,
      );

      expect(result.outcome, SlashCommandActionOutcome.unavailable);
      expect(result.command?.command, 'pets');
    },
  );

  test('/pets is unavailable during an active turn', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      configureTerminalPets: (_) async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/pets hide'),
      hasActiveTurn: true,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'pets');
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

  test(
    '/approve delegates to the injected auto-review approval action',
    () async {
      var approvals = 0;
      final dispatcher = SlashCommandActionDispatcher(
        approveRecentAutoReviewDenial: () async {
          approvals++;
          return SlashCommandCallbackResult.executed;
        },
      );

      final result = await dispatcher.dispatch(
        registry.parseComposerText('/approve'),
        hasActiveTurn: true,
      );

      expect(approvals, 1);
      expect(result.outcome, SlashCommandActionOutcome.executed);
      expect(result.effect, SlashCommandActionEffect.approveAutoReviewDenial);
    },
  );

  test('/approve rejects unsupported inline arguments', () async {
    var approvals = 0;
    final dispatcher = SlashCommandActionDispatcher(
      approveRecentAutoReviewDenial: () async {
        approvals++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/approve review_1'),
      hasActiveTurn: false,
    );

    expect(approvals, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'approve');
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

  test('/duplicate runs the injected duplicate action', () async {
    var duplicates = 0;
    final dispatcher = SlashCommandActionDispatcher(
      duplicateThread: () async {
        duplicates++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/duplicate'),
      hasActiveTurn: false,
    );

    expect(duplicates, 1);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.duplicateThread);
  });

  test('/rewind runs the injected rewind action with a turn id', () async {
    final rewindCalls = <String>[];
    final dispatcher = SlashCommandActionDispatcher(
      rewindThread: (lastTurnId) async {
        rewindCalls.add(lastTurnId);
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/rewind  turn_2  '),
      hasActiveTurn: false,
    );

    expect(rewindCalls, ['turn_2']);
    expect(result.outcome, SlashCommandActionOutcome.executed);
    expect(result.effect, SlashCommandActionEffect.rewindThread);
  });

  test('/rewind requires a turn id', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      rewindThread: (_) async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/rewind'),
      hasActiveTurn: false,
    );

    expect(calls, 0);
    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(result.command?.command, 'rewind');
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

  test('/side and /btw start side conversations with inline args', () async {
    final calls = <({String arguments, bool btw})>[];
    final dispatcher = SlashCommandActionDispatcher(
      startSideConversation: (arguments, {required bool btw}) async {
        calls.add((arguments: arguments, btw: btw));
        return SlashCommandCallbackResult.executed;
      },
    );

    final side = await dispatcher.dispatch(
      registry.parseComposerText('/side inspect this'),
      hasActiveTurn: false,
    );
    final btw = await dispatcher.dispatch(
      registry.parseComposerText('/btw quick question'),
      hasActiveTurn: false,
    );

    expect(calls, [
      (arguments: 'inspect this', btw: false),
      (arguments: 'quick question', btw: true),
    ]);
    expect(side.outcome, SlashCommandActionOutcome.executed);
    expect(side.effect, SlashCommandActionEffect.sideConversation);
    expect(btw.outcome, SlashCommandActionOutcome.executed);
    expect(btw.effect, SlashCommandActionEffect.sideConversation);
  });

  test('side conversations reject commands unavailable in side mode', () async {
    var forks = 0;
    var statuses = 0;
    final dispatcher = SlashCommandActionDispatcher(
      forkThread: () async {
        forks++;
        return SlashCommandCallbackResult.executed;
      },
      showStatus: () {
        statuses++;
        return 'Status summary';
      },
    );

    final fork = await dispatcher.dispatch(
      registry.parseComposerText('/fork'),
      hasActiveTurn: false,
      isSideConversation: true,
    );
    final status = await dispatcher.dispatch(
      registry.parseComposerText('/status'),
      hasActiveTurn: false,
      isSideConversation: true,
    );

    expect(fork.outcome, SlashCommandActionOutcome.unavailable);
    expect(fork.command?.command, 'fork');
    expect(status.outcome, SlashCommandActionOutcome.executed);
    expect(status.effect, SlashCommandActionEffect.status);
    expect(status.message, 'Status summary');
    expect(forks, 0);
    expect(statuses, 1);
  });

  test(
    'thread lifecycle commands are unavailable during an active turn',
    () async {
      var forkCalls = 0;
      var duplicateCalls = 0;
      var rewindCalls = 0;
      var compactCalls = 0;
      var archiveCalls = 0;
      var deleteCalls = 0;
      final dispatcher = SlashCommandActionDispatcher(
        forkThread: () async {
          forkCalls++;
          return SlashCommandCallbackResult.executed;
        },
        duplicateThread: () async {
          duplicateCalls++;
          return SlashCommandCallbackResult.executed;
        },
        rewindThread: (_) async {
          rewindCalls++;
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
      final duplicate = await dispatcher.dispatch(
        registry.parseComposerText('/duplicate'),
        hasActiveTurn: true,
      );
      final rewind = await dispatcher.dispatch(
        registry.parseComposerText('/rewind turn_2'),
        hasActiveTurn: true,
      );
      final compact = await dispatcher.dispatch(
        registry.parseComposerText('/compact'),
        hasActiveTurn: true,
      );

      expect(archive.outcome, SlashCommandActionOutcome.unavailable);
      expect(delete.outcome, SlashCommandActionOutcome.unavailable);
      expect(fork.outcome, SlashCommandActionOutcome.unavailable);
      expect(duplicate.outcome, SlashCommandActionOutcome.unavailable);
      expect(rewind.outcome, SlashCommandActionOutcome.unavailable);
      expect(compact.outcome, SlashCommandActionOutcome.unavailable);
      expect(forkCalls, 0);
      expect(duplicateCalls, 0);
      expect(rewindCalls, 0);
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

  test('/agent and /subagents open the topology browser', () async {
    final calls = <bool>[];
    final dispatcher = SlashCommandActionDispatcher(
      showAgentTopology: ({required bool subagentsOnly}) async {
        calls.add(subagentsOnly);
        return SlashCommandCallbackResult.executed;
      },
    );

    final agent = await dispatcher.dispatch(
      registry.parseComposerText('/agent'),
      hasActiveTurn: false,
    );
    final subagents = await dispatcher.dispatch(
      registry.parseComposerText('/subagents'),
      hasActiveTurn: false,
    );

    expect(calls, [false, true]);
    expect(agent.outcome, SlashCommandActionOutcome.executed);
    expect(agent.effect, SlashCommandActionEffect.agentTopology);
    expect(subagents.outcome, SlashCommandActionOutcome.executed);
    expect(subagents.effect, SlashCommandActionEffect.agentTopology);
  });

  test('/agent rejects unsupported inline arguments', () async {
    var calls = 0;
    final dispatcher = SlashCommandActionDispatcher(
      showAgentTopology: ({required bool subagentsOnly}) async {
        calls++;
        return SlashCommandCallbackResult.executed;
      },
    );

    final result = await dispatcher.dispatch(
      registry.parseComposerText('/agent thr_1'),
      hasActiveTurn: false,
    );

    expect(result.outcome, SlashCommandActionOutcome.unavailable);
    expect(calls, 0);
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
        registry.parseComposerText('/setup-default-sandbox'),
        hasActiveTurn: false,
      );
      final platformOnly = await dispatcher.dispatch(
        registry.parseComposerText('/pets'),
        hasActiveTurn: false,
      );
      final debugOnly = await dispatcher.dispatch(
        registry.parseComposerText('/test-approval'),
        hasActiveTurn: false,
      );

      expect(unknown.outcome, SlashCommandActionOutcome.unknown);
      expect(unknown.rawCommand, 'does-not-exist');
      expect(unsupported.outcome, SlashCommandActionOutcome.unsupported);
      expect(unsupported.command?.command, 'setup-default-sandbox');
      expect(platformOnly.outcome, SlashCommandActionOutcome.unsupported);
      expect(
        platformOnly.command?.mappingType,
        SlashCommandMappingType.notApplicable,
      );
      expect(debugOnly.outcome, SlashCommandActionOutcome.unsupported);
      expect(
        debugOnly.command?.platformVisibility,
        SlashPlatformVisibility.debugOnly,
      );
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
