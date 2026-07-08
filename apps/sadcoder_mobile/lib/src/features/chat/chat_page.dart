import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chat,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              _StateChip(label: l10n.disconnected),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MessageBlock(
                title: l10n.m0ProtocolClient,
                body: l10n.m0ProtocolClientBody,
              ),
              _MessageBlock(
                title: l10n.slashCommandSurface,
                body: l10n.slashCommandSurfaceBody,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: l10n.connectBeforeTurn,
                prefixIcon: const Icon(Icons.code),
                suffixIcon: IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.send),
                  tooltip: l10n.send,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.link_off, size: 18),
      label: Text(label),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
