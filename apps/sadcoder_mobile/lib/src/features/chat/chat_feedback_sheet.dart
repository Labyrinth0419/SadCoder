import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';

class ChatFeedbackFormResult {
  const ChatFeedbackFormResult({
    required this.category,
    required this.includeLogs,
    this.note,
  });

  final ChatFeedbackCategory category;
  final bool includeLogs;
  final String? note;
}

enum ChatFeedbackCategory { bug, badResult, goodResult, safetyCheck, other }

extension ChatFeedbackCategoryLabels on ChatFeedbackCategory {
  String get classification {
    return switch (this) {
      ChatFeedbackCategory.bug => 'bug',
      ChatFeedbackCategory.badResult => 'bad_result',
      ChatFeedbackCategory.goodResult => 'good_result',
      ChatFeedbackCategory.safetyCheck => 'safety_check',
      ChatFeedbackCategory.other => 'other',
    };
  }

  String label(AppLocalizations l10n) {
    return switch (this) {
      ChatFeedbackCategory.bug => l10n.feedbackCategoryBug,
      ChatFeedbackCategory.badResult => l10n.feedbackCategoryBadResult,
      ChatFeedbackCategory.goodResult => l10n.feedbackCategoryGoodResult,
      ChatFeedbackCategory.safetyCheck => l10n.feedbackCategorySafetyCheck,
      ChatFeedbackCategory.other => l10n.feedbackCategoryOther,
    };
  }
}

class ChatFeedbackSheet extends StatefulWidget {
  const ChatFeedbackSheet({super.key});

  @override
  State<ChatFeedbackSheet> createState() => _ChatFeedbackSheetState();
}

class _ChatFeedbackSheetState extends State<ChatFeedbackSheet> {
  final TextEditingController _noteController = TextEditingController();
  ChatFeedbackCategory _category = ChatFeedbackCategory.bug;
  bool _includeLogs = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.feedbackCommandTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<ChatFeedbackCategory>(
              key: const ValueKey('chat-feedback-category'),
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.feedbackCategoryLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final category in ChatFeedbackCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label(l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('chat-feedback-note'),
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.feedbackNoteLabel,
                hintText: l10n.feedbackNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.feedbackIncludeLogs),
              value: _includeLogs,
              onChanged: (value) => setState(() => _includeLogs = value),
            ),
            if (_includeLogs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.feedbackLogsDisclosure,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.approvalCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(l10n.feedbackSubmit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_includeLogs) {
      final confirmed = await _confirmIncludeLogs();
      if (!mounted || !confirmed) {
        return;
      }
    }
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      ChatFeedbackFormResult(
        category: _category,
        includeLogs: _includeLogs,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  Future<bool> _confirmIncludeLogs() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.info_outline),
        title: Text(l10n.feedbackLogsConfirmTitle),
        content: Text(l10n.feedbackLogsConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.feedbackLogsConfirmSubmit),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
