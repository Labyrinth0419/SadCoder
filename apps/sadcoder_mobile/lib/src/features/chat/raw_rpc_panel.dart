import 'dart:convert';

import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';

typedef RawRpcSender =
    Future<Map<String, Object?>> Function({
      required String method,
      Map<String, Object?>? params,
    });

class RawRpcPanel extends StatefulWidget {
  const RawRpcPanel({super.key, required this.onSend});

  final RawRpcSender? onSend;

  @override
  State<RawRpcPanel> createState() => _RawRpcPanelState();
}

class _RawRpcPanelState extends State<RawRpcPanel> {
  final TextEditingController _methodController = TextEditingController();
  final TextEditingController _paramsController = TextEditingController(
    text: '{}',
  );
  bool _confirmed = false;
  bool _submitting = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _methodController.dispose();
    _paramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final connected = widget.onSend != null;
    return DecoratedBox(
      key: const ValueKey('chat-raw-rpc-panel'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            Icons.api_outlined,
            color: connected ? null : colorScheme.outline,
          ),
          title: Text(l10n.rawRpcTitle, style: theme.textTheme.titleSmall),
          subtitle: Text(
            connected ? l10n.rawRpcDescription : l10n.rawRpcDisconnected,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            TextField(
              key: const ValueKey('chat-raw-rpc-method-field'),
              controller: _methodController,
              enabled: connected && !_submitting,
              minLines: 1,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: l10n.rawRpcMethod,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('chat-raw-rpc-params-field'),
              controller: _paramsController,
              enabled: connected && !_submitting,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.rawRpcParams,
                isDense: true,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              key: const ValueKey('chat-raw-rpc-confirm'),
              value: _confirmed,
              onChanged: connected && !_submitting
                  ? (value) => setState(() => _confirmed = value ?? false)
                  : null,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.rawRpcConfirm),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('chat-raw-rpc-send'),
                onPressed: _canSend ? _send : null,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(l10n.rawRpcSend),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              _RawRpcOutput(
                key: const ValueKey('chat-raw-rpc-error'),
                title: l10n.rawRpcError,
                text: _error!,
                color: colorScheme.error,
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 8),
              _RawRpcOutput(
                key: const ValueKey('chat-raw-rpc-result'),
                title: l10n.rawRpcResult,
                text: _result!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _canSend =>
      widget.onSend != null &&
      !_submitting &&
      _confirmed &&
      _methodController.text.trim().isNotEmpty;

  Future<void> _send() async {
    final l10n = context.l10n;
    final sender = widget.onSend;
    if (sender == null) {
      return;
    }
    final method = _methodController.text.trim();
    if (method.isEmpty) {
      setState(() {
        _error = l10n.rawRpcMethodRequired;
        _result = null;
      });
      return;
    }
    final params = _parseParams(l10n);
    if (_error != null) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await sender(method: method, params: params);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = const JsonEncoder.withIndent('  ').convert(result);
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Map<String, Object?>? _parseParams(AppLocalizations l10n) {
    final raw = _paramsController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = null);
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded == null) {
        setState(() => _error = null);
        return null;
      }
      if (decoded is Map) {
        setState(() => _error = null);
        return Map<String, Object?>.from(decoded);
      }
    } on Object catch (error) {
      setState(
        () => _error = l10n.messageWithDetail(
          l10n.rawRpcInvalidJsonObject,
          error,
        ),
      );
      return null;
    }
    setState(() => _error = l10n.rawRpcInvalidJsonObject);
    return null;
  }
}

class _RawRpcOutput extends StatelessWidget {
  const _RawRpcOutput({
    super.key,
    required this.title,
    required this.text,
    this.color,
  });

  final String title;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(color: foreground),
            ),
            const SizedBox(height: 6),
            SelectableText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
