import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Chat',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const _StateChip(label: 'Disconnected'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _MessageBlock(
                title: 'M0 protocol client',
                body:
                    'The app has a JSON-RPC client for initialize, model/list, and thread/list. SSH transport will plug into the same interface.',
              ),
              _MessageBlock(
                title: 'Slash command surface',
                body:
                    'Typing / will later open the SadCoder command palette instead of sending slash text as a normal prompt.',
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
                hintText: 'Connect to a host before sending a turn',
                prefixIcon: const Icon(Icons.code),
                suffixIcon: IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.send),
                  tooltip: 'Send',
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
