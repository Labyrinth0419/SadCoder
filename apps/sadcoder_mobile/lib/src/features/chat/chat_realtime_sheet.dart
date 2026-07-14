import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../realtime/realtime_runner.dart';

Future<void> showChatRealtimeSheet({
  required BuildContext context,
  required RealtimeRunner? runner,
  required String? threadId,
}) async {
  final realtime = runner;
  final normalizedThreadId = threadId?.trim();
  if (realtime == null ||
      normalizedThreadId == null ||
      normalizedThreadId.isEmpty) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        ChatRealtimeSheet(runner: realtime, threadId: normalizedThreadId),
  );
}

class ChatRealtimeSheet extends StatefulWidget {
  const ChatRealtimeSheet({
    super.key,
    required this.runner,
    required this.threadId,
  });

  final RealtimeRunner runner;
  final String threadId;

  @override
  State<ChatRealtimeSheet> createState() => _ChatRealtimeSheetState();
}

class _ChatRealtimeSheetState extends State<ChatRealtimeSheet> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final List<_RealtimeTranscriptEntry> _entries = [];
  StreamSubscription<ThreadRealtimeEvent>? _subscription;
  RealtimeConversationVersion? _version;
  RealtimeTextRole _role = RealtimeTextRole.user;
  RealtimeVoiceCatalog? _voices;
  Object? _error;
  _RealtimeStatus _status = _RealtimeStatus.idle;
  bool _includeStartupContext = true;
  bool _closing = false;

  bool get _isRunning =>
      _status == _RealtimeStatus.starting || _status == _RealtimeStatus.active;

  @override
  void initState() {
    super.initState();
    _subscription = widget.runner.events
        .where((event) => event.threadId == widget.threadId)
        .listen(_handleEvent);
    unawaited(_loadVoices());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _messageController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_close());
        }
      },
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.realtimeTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('chat-realtime-close'),
                    onPressed: _closing ? null : _close,
                    icon: const Icon(Icons.close),
                    tooltip: l10n.close,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(status: _status),
                  Text(l10n.realtimeTransportWebsocket),
                  if (_voices != null)
                    Text(
                      l10n.realtimeProtocolSummary(
                        _voices!.v1.length,
                        _voices!.v2.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.messageWithDetail(l10n.realtimeFailed, _error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _StartOptions(
                version: _version,
                onVersionChanged: _isRunning
                    ? null
                    : (value) => setState(() => _version = value),
                modelController: _modelController,
                promptController: _promptController,
                includeStartupContext: _includeStartupContext,
                onIncludeStartupContextChanged: _isRunning
                    ? null
                    : (value) => setState(() => _includeStartupContext = value),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _entries.isEmpty
                      ? Center(child: Text(l10n.realtimeEmpty))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) =>
                              _TranscriptTile(entry: _entries[index]),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  DropdownButton<RealtimeTextRole>(
                    key: const ValueKey('chat-realtime-role'),
                    value: _role,
                    onChanged: _isRunning
                        ? (value) {
                            if (value != null) {
                              setState(() => _role = value);
                            }
                          }
                        : null,
                    items: [
                      for (final role in RealtimeTextRole.values)
                        DropdownMenuItem(
                          value: role,
                          child: Text(role.wireName),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-realtime-message'),
                      controller: _messageController,
                      enabled: _isRunning,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: l10n.realtimeMessageHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => unawaited(_appendText()),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('chat-realtime-send'),
                    onPressed: _isRunning ? _appendText : null,
                    icon: const Icon(Icons.send),
                    tooltip: l10n.send,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('chat-realtime-start'),
                    onPressed:
                        _status == _RealtimeStatus.idle ||
                            _status == _RealtimeStatus.closed ||
                            _status == _RealtimeStatus.failed
                        ? _start
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.realtimeStart),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const ValueKey('chat-realtime-stop'),
                    onPressed: _isRunning ? _stop : null,
                    icon: const Icon(Icons.stop),
                    label: Text(l10n.realtimeStop),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await widget.runner.listVoices();
      if (mounted) {
        setState(() => _voices = voices);
      }
    } on Object {
      // Voice discovery is informational for text-only mode.
    }
  }

  void _handleEvent(ThreadRealtimeEvent event) {
    if (!mounted) {
      return;
    }
    setState(() {
      switch (event.kind) {
        case ThreadRealtimeEventKind.started:
          _status = _RealtimeStatus.active;
          _error = null;
        case ThreadRealtimeEventKind.transcriptDelta:
          _appendTranscriptDelta(event.role ?? 'assistant', event.delta ?? '');
        case ThreadRealtimeEventKind.transcriptDone:
          _completeTranscript(event.role ?? 'assistant', event.text ?? '');
        case ThreadRealtimeEventKind.itemAdded:
          _entries.add(
            _RealtimeTranscriptEntry(
              role: 'event',
              text: _formatItem(event.item),
              finalText: true,
            ),
          );
        case ThreadRealtimeEventKind.error:
          _status = _RealtimeStatus.failed;
          _error = StateError(event.message ?? context.l10n.realtimeFailed);
        case ThreadRealtimeEventKind.closed:
          _status = _RealtimeStatus.closed;
        case ThreadRealtimeEventKind.sdp ||
            ThreadRealtimeEventKind.outputAudioDelta:
          // Text mode should not receive either event; keep the raw session alive.
          break;
      }
    });
  }

  Future<void> _start() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = _RealtimeStatus.starting;
      _error = null;
      _entries.clear();
    });
    try {
      await widget.runner.startText(
        threadId: widget.threadId,
        version: _version,
        model: _modelController.text,
        prompt: _promptController.text,
        includeStartupContext: _includeStartupContext,
        codexResponsesAsItems: true,
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _status = _RealtimeStatus.failed;
          _error = error;
        });
      }
    }
  }

  Future<void> _appendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isRunning) {
      return;
    }
    _messageController.clear();
    _appendTranscriptDelta(_role.wireName, text, finalText: true);
    try {
      await widget.runner.appendText(
        threadId: widget.threadId,
        text: text,
        role: _role,
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _stop() async {
    if (!_isRunning) {
      return;
    }
    setState(() => _status = _RealtimeStatus.stopping);
    try {
      await widget.runner.stop(threadId: widget.threadId);
      if (mounted && _status == _RealtimeStatus.stopping) {
        setState(() => _status = _RealtimeStatus.closed);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _status = _RealtimeStatus.failed;
          _error = error;
        });
      }
    }
  }

  Future<void> _close() async {
    if (_closing) {
      return;
    }
    if (_isRunning) {
      final shouldStop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.realtimeStopTitle),
          content: Text(context.l10n.realtimeStopBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.approvalCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.realtimeStop),
            ),
          ],
        ),
      );
      if (shouldStop != true || !mounted) {
        return;
      }
      await _stop();
      if (!mounted || _isRunning) {
        return;
      }
    }
    setState(() => _closing = true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _appendTranscriptDelta(
    String role,
    String delta, {
    bool finalText = false,
  }) {
    if (delta.isEmpty) {
      return;
    }
    if (_entries.isNotEmpty &&
        _entries.last.role == role &&
        !_entries.last.finalText) {
      _entries.last.text += delta;
      if (finalText) {
        _entries.last.finalText = true;
      }
      return;
    }
    _entries.add(
      _RealtimeTranscriptEntry(role: role, text: delta, finalText: finalText),
    );
  }

  void _completeTranscript(String role, String text) {
    if (_entries.isNotEmpty &&
        _entries.last.role == role &&
        !_entries.last.finalText) {
      _entries.last.text = text;
      _entries.last.finalText = true;
      return;
    }
    if (text.isNotEmpty) {
      _entries.add(
        _RealtimeTranscriptEntry(role: role, text: text, finalText: true),
      );
    }
  }
}

enum _RealtimeStatus { idle, starting, active, stopping, closed, failed }

class _RealtimeTranscriptEntry {
  _RealtimeTranscriptEntry({
    required this.role,
    required this.text,
    required this.finalText,
  });

  final String role;
  String text;
  bool finalText;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _RealtimeStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.name),
      avatar: Icon(
        status == _RealtimeStatus.active
            ? Icons.circle
            : Icons.radio_button_unchecked,
        size: 12,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StartOptions extends StatelessWidget {
  const _StartOptions({
    required this.version,
    required this.onVersionChanged,
    required this.modelController,
    required this.promptController,
    required this.includeStartupContext,
    required this.onIncludeStartupContextChanged,
  });

  final RealtimeConversationVersion? version;
  final ValueChanged<RealtimeConversationVersion?>? onVersionChanged;
  final TextEditingController modelController;
  final TextEditingController promptController;
  final bool includeStartupContext;
  final ValueChanged<bool>? onIncludeStartupContextChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpansionTile(
      key: const ValueKey('chat-realtime-options'),
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: false,
      title: Text(l10n.realtimeOptions),
      children: [
        Row(
          children: [
            Text(l10n.realtimeVersion),
            const SizedBox(width: 8),
            DropdownButton<RealtimeConversationVersion?>(
              value: version,
              onChanged: onVersionChanged,
              items: [
                DropdownMenuItem<RealtimeConversationVersion?>(
                  value: null,
                  child: Text(l10n.serverDefaultOption),
                ),
                for (final value in RealtimeConversationVersion.values)
                  DropdownMenuItem(value: value, child: Text(value.wireName)),
              ],
            ),
          ],
        ),
        TextField(
          key: const ValueKey('chat-realtime-model'),
          controller: modelController,
          enabled: onVersionChanged != null,
          decoration: InputDecoration(
            labelText: l10n.modelOverride,
            isDense: true,
          ),
        ),
        TextField(
          key: const ValueKey('chat-realtime-prompt'),
          controller: promptController,
          enabled: onVersionChanged != null,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.realtimePrompt,
            isDense: true,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.realtimeIncludeStartupContext),
          value: includeStartupContext,
          onChanged: onIncludeStartupContextChanged,
        ),
      ],
    );
  }
}

class _TranscriptTile extends StatelessWidget {
  const _TranscriptTile({required this.entry});

  final _RealtimeTranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == 'user';
    final isEvent = entry.role == 'event';
    final title = isEvent ? 'event' : entry.role;
    final text = entry.text;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isEvent
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 3),
            Text(text),
          ],
        ),
      ),
    );
  }
}

String _formatItem(Map<String, Object?>? item) {
  if (item == null || item.isEmpty) {
    return 'realtime item';
  }
  final type = item['type'];
  final text = item['text'] ?? item['content'];
  if (text is String && text.trim().isNotEmpty) {
    return '${type ?? 'item'}: ${text.trim()}';
  }
  try {
    return jsonEncode(item);
  } on Object {
    return item.toString();
  }
}
