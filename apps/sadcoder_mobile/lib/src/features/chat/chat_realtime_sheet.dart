import 'dart:collection';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../realtime/method_channel_realtime_audio_device.dart';
import '../../realtime/realtime_audio_device.dart';
import '../../realtime/realtime_runner.dart';

Future<void> showChatRealtimeSheet({
  required BuildContext context,
  required RealtimeRunner? runner,
  required String? threadId,
  RealtimeAudioDevice? audioDevice,
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
    builder: (_) => ChatRealtimeSheet(
      runner: realtime,
      threadId: normalizedThreadId,
      audioDevice: audioDevice,
    ),
  );
}

class ChatRealtimeSheet extends StatefulWidget {
  const ChatRealtimeSheet({
    super.key,
    required this.runner,
    required this.threadId,
    this.audioDevice,
  });

  final RealtimeRunner runner;
  final String threadId;
  final RealtimeAudioDevice? audioDevice;

  @override
  State<ChatRealtimeSheet> createState() => _ChatRealtimeSheetState();
}

class _ChatRealtimeSheetState extends State<ChatRealtimeSheet> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final List<_RealtimeTranscriptEntry> _entries = [];
  StreamSubscription<ThreadRealtimeEvent>? _subscription;
  StreamSubscription<RealtimeAudioFrame>? _audioSubscription;
  RealtimeConversationVersion? _version;
  RealtimeTextRole _role = RealtimeTextRole.user;
  RealtimeVoiceCatalog? _voices;
  RealtimeAudioDevice? _audioDevice;
  final ListQueue<RealtimeAudioFrame> _pendingAudioFrames = ListQueue();
  bool _sendingAudio = false;
  bool _audioForwarding = false;
  _RealtimeMode _mode = _RealtimeMode.text;
  String? _voice;
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
    unawaited(_audioSubscription?.cancel());
    unawaited(_stopLocalAudio());
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
              SegmentedButton<_RealtimeMode>(
                key: const ValueKey('chat-realtime-mode'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _RealtimeMode.text,
                    icon: const Icon(Icons.text_fields),
                    label: Text(l10n.realtimeModeText),
                  ),
                  ButtonSegment(
                    value: _RealtimeMode.audio,
                    icon: const Icon(Icons.mic),
                    label: Text(l10n.realtimeModeAudio),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _isRunning
                    ? null
                    : (selection) => _changeMode(selection.single),
              ),
              const SizedBox(height: 8),
              _StartOptions(
                mode: _mode,
                version: _version,
                onVersionChanged: _isRunning ? null : _changeVersion,
                voices: _availableVoices,
                voice: _voice,
                onVoiceChanged: _isRunning || _mode != _RealtimeMode.audio
                    ? null
                    : (value) => setState(() => _voice = value),
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
              if (_mode == _RealtimeMode.text) ...[
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
              ],
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
        setState(() {
          _voices = voices;
          _voice ??= _defaultVoice;
        });
      }
    } on Object {
      // Voice discovery is informational until audio mode is selected.
    }
  }

  List<String> get _availableVoices {
    final voices = _voices;
    if (voices == null) {
      return const [];
    }
    return switch (_version) {
      RealtimeConversationVersion.v1 => voices.v1,
      RealtimeConversationVersion.v2 => voices.v2,
      null => voices.v2.isNotEmpty ? voices.v2 : voices.v1,
    };
  }

  String? get _defaultVoice {
    final voices = _voices;
    if (voices == null) {
      return null;
    }
    return switch (_version) {
      RealtimeConversationVersion.v1 =>
        voices.defaultV1 ?? _firstOrNull(voices.v1),
      RealtimeConversationVersion.v2 =>
        voices.defaultV2 ?? _firstOrNull(voices.v2),
      null =>
        voices.defaultV2 ??
            voices.defaultV1 ??
            (voices.v2.isNotEmpty ? voices.v2.first : _firstOrNull(voices.v1)),
    };
  }

  void _changeMode(_RealtimeMode mode) {
    if (_isRunning || mode == _mode) {
      return;
    }
    setState(() {
      _mode = mode;
      if (mode == _RealtimeMode.audio) {
        _voice ??= _defaultVoice;
      } else {
        _voice = null;
      }
    });
  }

  void _changeVersion(RealtimeConversationVersion? version) {
    if (_isRunning) {
      return;
    }
    setState(() {
      _version = version;
      final voices = _availableVoices;
      _voice = voices.contains(_voice) ? _voice : _defaultVoice;
    });
  }

  void _handleEvent(ThreadRealtimeEvent event) {
    if (!mounted) {
      return;
    }
    RealtimeAudioFrame? outputAudio;
    var releaseAudio = false;
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
          _audioForwarding = false;
          releaseAudio = true;
        case ThreadRealtimeEventKind.closed:
          _status = _RealtimeStatus.closed;
          _audioForwarding = false;
          releaseAudio = true;
        case ThreadRealtimeEventKind.outputAudioDelta:
          outputAudio = event.audioFrame;
        case ThreadRealtimeEventKind.sdp:
          // WebRTC negotiation is intentionally outside this WebSocket milestone.
          break;
      }
    });
    final audio = outputAudio;
    if (audio != null && _mode == _RealtimeMode.audio) {
      unawaited(_playAudio(audio));
    }
    if (releaseAudio) {
      unawaited(_stopLocalAudio());
    }
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
      if (_mode == _RealtimeMode.audio) {
        await _startLocalAudio();
        await widget.runner.startAudio(
          threadId: widget.threadId,
          version: _version,
          voice: _voice,
          model: _modelController.text,
          prompt: _promptController.text,
          includeStartupContext: _includeStartupContext,
          codexResponsesAsItems: true,
        );
        _audioForwarding = true;
        if (_pendingAudioFrames.isNotEmpty) {
          unawaited(_drainAudioFrames());
        }
      } else {
        await widget.runner.startText(
          threadId: widget.threadId,
          version: _version,
          model: _modelController.text,
          prompt: _promptController.text,
          includeStartupContext: _includeStartupContext,
          codexResponsesAsItems: true,
        );
      }
    } on Object catch (error) {
      await _stopLocalAudio();
      if (mounted) {
        setState(() {
          _status = _RealtimeStatus.failed;
          _error = error;
        });
      }
    }
  }

  Future<void> _startLocalAudio() async {
    final device = _audioDevice ??=
        widget.audioDevice ?? MethodChannelRealtimeAudioDevice();
    await _audioSubscription?.cancel();
    _audioSubscription = device.capturedFrames.listen(
      _queueAudioFrame,
      onError: _handleAudioDeviceError,
    );
    await device.startCapture();
  }

  void _queueAudioFrame(RealtimeAudioFrame frame) {
    if (!_audioForwarding && _status != _RealtimeStatus.starting) {
      return;
    }
    if (_pendingAudioFrames.length >= 12) {
      _pendingAudioFrames.removeFirst();
    }
    _pendingAudioFrames.addLast(frame);
    if (!_sendingAudio) {
      unawaited(_drainAudioFrames());
    }
  }

  Future<void> _drainAudioFrames() async {
    if (_sendingAudio) {
      return;
    }
    _sendingAudio = true;
    try {
      while (_audioForwarding && _pendingAudioFrames.isNotEmpty) {
        final frame = _pendingAudioFrames.removeFirst();
        try {
          await widget.runner.appendAudio(
            threadId: widget.threadId,
            audio: frame,
          );
        } on Object catch (error) {
          _pendingAudioFrames.clear();
          _audioForwarding = false;
          if (mounted) {
            setState(() {
              _status = _RealtimeStatus.failed;
              _error = error;
            });
          }
          unawaited(_stopLocalAudio());
          unawaited(_stopServerAfterAudioFailure());
          break;
        }
      }
    } finally {
      _sendingAudio = false;
    }
  }

  void _handleAudioDeviceError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }
    _audioForwarding = false;
    setState(() {
      _status = _RealtimeStatus.failed;
      _error = error;
    });
    unawaited(_stopLocalAudio());
    unawaited(_stopServerAfterAudioFailure());
  }

  Future<void> _stopServerAfterAudioFailure() async {
    try {
      await widget.runner.stop(threadId: widget.threadId);
    } on Object {
      // Preserve the device error; the server may already have closed.
    }
  }

  Future<void> _playAudio(RealtimeAudioFrame frame) async {
    final device = _audioDevice;
    if (device == null) {
      return;
    }
    try {
      await device.play(frame);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _stopLocalAudio() async {
    _audioForwarding = false;
    _pendingAudioFrames.clear();
    final subscription = _audioSubscription;
    _audioSubscription = null;
    unawaited(subscription?.cancel());
    final device = _audioDevice;
    if (device == null) {
      return;
    }
    Object? cleanupError;
    try {
      await device.stopCapture();
    } on Object catch (error) {
      cleanupError = error;
    }
    try {
      await device.stopPlayback();
    } on Object catch (error) {
      cleanupError ??= error;
    }
    if (cleanupError != null && mounted && _error == null) {
      setState(() => _error = cleanupError);
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
    _audioForwarding = false;
    _pendingAudioFrames.clear();
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
    } finally {
      await _stopLocalAudio();
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
    await _stopLocalAudio();
    if (!mounted) {
      return;
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

enum _RealtimeMode { text, audio }

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
    required this.mode,
    required this.version,
    required this.onVersionChanged,
    required this.voices,
    required this.voice,
    required this.onVoiceChanged,
    required this.modelController,
    required this.promptController,
    required this.includeStartupContext,
    required this.onIncludeStartupContextChanged,
  });

  final _RealtimeMode mode;
  final RealtimeConversationVersion? version;
  final ValueChanged<RealtimeConversationVersion?>? onVersionChanged;
  final List<String> voices;
  final String? voice;
  final ValueChanged<String?>? onVoiceChanged;
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
        if (mode == _RealtimeMode.audio)
          Row(
            children: [
              Text(l10n.realtimeVoice),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String?>(
                  key: const ValueKey('chat-realtime-voice'),
                  isExpanded: true,
                  value: voices.contains(voice) ? voice : null,
                  onChanged: onVoiceChanged,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.serverDefaultOption),
                    ),
                    for (final value in voices)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                ),
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

String? _firstOrNull(List<String> values) =>
    values.isEmpty ? null : values.first;
