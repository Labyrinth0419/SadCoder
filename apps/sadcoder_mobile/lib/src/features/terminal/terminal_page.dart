import 'dart:async';

import 'package:flutter/material.dart';

import '../../command_exec/command_exec_runner.dart';
import '../../i18n/app_localizations.dart';
import '../../theme/sadcoder_theme.dart';
import 'terminal_session_controller.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({
    super.key,
    this.runner,
    this.root,
    TerminalSessionController? controller,
  }) : _controller = controller;

  final CommandExecRunner? runner;
  final String? root;
  final TerminalSessionController? _controller;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _stdinController = TextEditingController();
  late TerminalSessionController _sessionController;
  bool _ownsSessionController = false;

  @override
  void initState() {
    super.initState();
    _commandController.addListener(_handleTextChanged);
    _sessionController =
        widget._controller ??
        TerminalSessionController(runnerProvider: () => widget.runner);
    _ownsSessionController = widget._controller == null;
    _sessionController.addListener(_handleSessionChanged);
  }

  @override
  void didUpdateWidget(TerminalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._controller != widget._controller) {
      _sessionController.removeListener(_handleSessionChanged);
      if (_ownsSessionController) {
        _sessionController.dispose();
      }
      _sessionController =
          widget._controller ??
          TerminalSessionController(runnerProvider: () => widget.runner);
      _ownsSessionController = widget._controller == null;
      _sessionController.addListener(_handleSessionChanged);
    }
  }

  @override
  void dispose() {
    _commandController
      ..removeListener(_handleTextChanged)
      ..dispose();
    _stdinController.dispose();
    _sessionController.removeListener(_handleSessionChanged);
    if (_ownsSessionController) {
      _sessionController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final root = _normalizedText(widget.root);
    final runner = widget.runner;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.terminalTitle)),
      body: ListView(
        key: const ValueKey('terminal-page'),
        padding: const EdgeInsets.all(16),
        children: [
          _TerminalHeader(root: root),
          const SizedBox(height: 12),
          if (runner == null)
            _TerminalStatusPanel(
              icon: Icons.link_off,
              title: l10n.terminalNotConnected,
            )
          else if (root == null)
            _TerminalStatusPanel(
              icon: Icons.folder_off_outlined,
              title: l10n.terminalNoCwd,
            )
          else ...[
            _CommandForm(
              controller: _commandController,
              canRun: _canRun,
              onRun: () => unawaited(_run(root)),
            ),
            const SizedBox(height: 12),
            _TerminalOutputPanel(controller: _sessionController),
            const SizedBox(height: 12),
            _TerminalControls(
              enabled: _sessionController.isRunning,
              stdinController: _stdinController,
              onSend: _sendInput,
              onCloseStdin: () => unawaited(_sessionController.closeStdin()),
              onTerminate: () => unawaited(_sessionController.terminate()),
            ),
          ],
        ],
      ),
    );
  }

  bool get _canRun {
    return !_sessionController.isRunning &&
        parseCommandExecArgv(_commandController.text).isNotEmpty &&
        widget.runner != null &&
        _normalizedText(widget.root) != null;
  }

  Future<void> _run(String root) async {
    if (!_canRun) {
      return;
    }
    await _sessionController.start(
      commandLine: _commandController.text,
      cwd: root,
    );
  }

  Future<void> _sendInput() async {
    final text = _stdinController.text;
    if (text.isEmpty) {
      return;
    }
    await _sessionController.sendInput('$text\n');
    _stdinController.clear();
  }

  void _handleTextChanged() => setState(() {});

  void _handleSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader({required this.root});

  final String? root;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.terminalTitle, style: Theme.of(context).textTheme.titleLarge),
        if (root != null) ...[
          const SizedBox(height: 4),
          Text(l10n.terminalCwd(root!)),
        ],
      ],
    );
  }
}

class _CommandForm extends StatelessWidget {
  const _CommandForm({
    required this.controller,
    required this.canRun,
    required this.onRun,
  });

  final TextEditingController controller;
  final bool canRun;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('terminal-command-field'),
            controller: controller,
            decoration: InputDecoration(labelText: l10n.terminalCommand),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canRun) {
                onRun();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          key: const ValueKey('terminal-run-button'),
          tooltip: l10n.terminalRun,
          onPressed: canRun ? onRun : null,
          icon: const Icon(Icons.play_arrow),
        ),
      ],
    );
  }
}

class _TerminalOutputPanel extends StatelessWidget {
  const _TerminalOutputPanel({required this.controller});

  final TerminalSessionController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sadCoderColors = theme.extension<SadCoderThemeColors>();
    final output = controller.output.isEmpty
        ? l10n.terminalNoOutput
        : controller.output;
    return Container(
      key: const ValueKey('terminal-output-panel'),
      constraints: const BoxConstraints(minHeight: 220),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            sadCoderColors?.terminalBackground ??
            theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLabel(l10n, controller),
            style: theme.textTheme.labelMedium?.copyWith(
              color: sadCoderColors?.terminalForeground,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            output,
            key: const ValueKey('terminal-output-text'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              color: sadCoderColors?.terminalForeground,
            ),
          ),
          if (controller.outputCapReached) ...[
            const SizedBox(height: 8),
            Text(l10n.terminalOutputCapped),
          ],
        ],
      ),
    );
  }
}

class _TerminalControls extends StatelessWidget {
  const _TerminalControls({
    required this.enabled,
    required this.stdinController,
    required this.onSend,
    required this.onCloseStdin,
    required this.onTerminate,
  });

  final bool enabled;
  final TextEditingController stdinController;
  final VoidCallback onSend;
  final VoidCallback onCloseStdin;
  final VoidCallback onTerminate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('terminal-stdin-field'),
          controller: stdinController,
          enabled: enabled,
          decoration: InputDecoration(labelText: l10n.terminalInput),
          textInputAction: TextInputAction.send,
          onSubmitted: enabled ? (_) => onSend() : null,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            IconButton.outlined(
              key: const ValueKey('terminal-stdin-send'),
              tooltip: l10n.terminalSendInput,
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.keyboard_return),
            ),
            IconButton.outlined(
              key: const ValueKey('terminal-close-stdin'),
              tooltip: l10n.terminalCloseStdin,
              onPressed: enabled ? onCloseStdin : null,
              icon: const Icon(Icons.vertical_align_bottom),
            ),
            IconButton.filledTonal(
              key: const ValueKey('terminal-terminate'),
              tooltip: l10n.terminalTerminate,
              onPressed: enabled ? onTerminate : null,
              icon: const Icon(Icons.stop),
            ),
          ],
        ),
      ],
    );
  }
}

class _TerminalStatusPanel extends StatelessWidget {
  const _TerminalStatusPanel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
        ],
      ),
    );
  }
}

String _statusLabel(
  AppLocalizations l10n,
  TerminalSessionController controller,
) {
  return switch (controller.status) {
    TerminalSessionStatus.idle => l10n.terminalIdle,
    TerminalSessionStatus.starting => l10n.terminalStarting,
    TerminalSessionStatus.running => l10n.terminalRunning,
    TerminalSessionStatus.completed => l10n.terminalExitCode(
      controller.exitCode ?? -1,
    ),
    TerminalSessionStatus.failed => l10n.terminalFailed(
      _terminalFailureDetail(l10n, controller.error),
    ),
  };
}

String _terminalFailureDetail(AppLocalizations l10n, Object? error) {
  if (error is TerminalSessionException) {
    return switch (error.code) {
      TerminalSessionFailure.noActiveCommandExecSession =>
        l10n.terminalNoActiveCommandExecSession,
    };
  }
  return error?.toString() ?? l10n.terminalUnknownFailure;
}

String? _normalizedText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
