import 'package:flutter/material.dart';

import '../../commands/slash_command_registry.dart';
import '../../i18n/app_localizations.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.registry = const SlashCommandRegistry()});

  final SlashCommandRegistry registry;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  SlashCommandParseResult _slashCommand =
      const SlashCommandParseResult.notSlash();

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
              _SlashCommandPreview(result: _slashCommand),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const ValueKey('chat-composer-field'),
              onChanged: _handleComposerChanged,
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

  void _handleComposerChanged(String value) {
    setState(() => _slashCommand = widget.registry.parseComposerText(value));
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

class _SlashCommandPreview extends StatelessWidget {
  const _SlashCommandPreview({required this.result});

  final SlashCommandParseResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (result.kind) {
      SlashCommandParseKind.notSlash => const SizedBox.shrink(),
      SlashCommandParseKind.empty => _PreviewCard(
        icon: Icons.manage_search,
        title: l10n.slashCommands,
        subtitle: l10n.typeCommandName,
      ),
      SlashCommandParseKind.unknown => _PreviewCard(
        icon: Icons.error_outline,
        title: l10n.slashCommandUnknown('/${result.rawCommand}'),
        subtitle: l10n.slashCommandNotSentAsPrompt,
      ),
      SlashCommandParseKind.known => _PreviewCard(
        icon: Icons.terminal,
        title: result.command!.slash,
        subtitle: result.command!.description,
      ),
    };
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
