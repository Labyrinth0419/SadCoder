import 'dart:async';

import 'package:flutter/material.dart';

import '../../approvals/pending_approval.dart';
import '../../i18n/app_localizations.dart';

typedef ToolUserInputFormSubmitCallback =
    FutureOr<void> Function(Map<String, List<String>> answers);

class ToolUserInputForm extends StatefulWidget {
  const ToolUserInputForm({
    super.key,
    required this.questions,
    required this.onSubmit,
    this.autoResolutionMs,
  });

  final List<ToolUserInputQuestion> questions;
  final int? autoResolutionMs;
  final ToolUserInputFormSubmitCallback? onSubmit;

  @override
  State<ToolUserInputForm> createState() => _ToolUserInputFormState();
}

class _ToolUserInputFormState extends State<ToolUserInputForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String?> _selections = {};
  final Set<String> _visibleSecrets = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _syncQuestions();
  }

  @override
  void didUpdateWidget(ToolUserInputForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncQuestions();
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = widget.onSubmit != null && !_submitting;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.autoResolutionMs case final milliseconds?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.schedule_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.toolUserInputAutoResolution(
                        (milliseconds / 1000).ceil(),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          for (var index = 0; index < widget.questions.length; index++) ...[
            if (index > 0) const Divider(height: 32),
            _buildQuestion(context, widget.questions[index], enabled),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('tool-user-input-submit'),
              onPressed: enabled ? _submit : null,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _submitting
                    ? l10n.toolUserInputSubmitting
                    : l10n.toolUserInputSubmit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(
    BuildContext context,
    ToolUserInputQuestion question,
    bool enabled,
  ) {
    final l10n = context.l10n;
    final options = question.options;
    final hasOptions = options?.isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.header.isNotEmpty)
          Text(question.header, style: Theme.of(context).textTheme.titleSmall),
        if (question.header.isNotEmpty && question.question.isNotEmpty)
          const SizedBox(height: 4),
        if (question.question.isNotEmpty)
          Text(
            question.question,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        const SizedBox(height: 8),
        if (hasOptions)
          FormField<String>(
            key: ValueKey('tool-user-input-selection-${question.id}'),
            initialValue: _selections[question.id],
            validator: (value) =>
                value == null ? l10n.toolUserInputSelectionRequired : null,
            builder: (field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioGroup<String>(
                    groupValue: _selections[question.id],
                    onChanged: enabled
                        ? (value) {
                            setState(() {
                              _selections[question.id] = value;
                              field.didChange(value);
                            });
                          }
                        : (_) {},
                    child: Column(
                      children: [
                        for (
                          var optionIndex = 0;
                          optionIndex < options!.length;
                          optionIndex++
                        )
                          RadioListTile<String>(
                            key: ValueKey(
                              'tool-user-input-${question.id}-option-'
                              '$optionIndex',
                            ),
                            value: options[optionIndex].label,
                            enabled: enabled,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(options[optionIndex].label),
                            subtitle: options[optionIndex].description.isEmpty
                                ? null
                                : Text(options[optionIndex].description),
                          ),
                        if (question.isOther)
                          RadioListTile<String>(
                            key: ValueKey(
                              'tool-user-input-${question.id}-other',
                            ),
                            value: _otherValue(question.id),
                            enabled: enabled,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(l10n.toolUserInputOther),
                            subtitle: Text(l10n.toolUserInputOtherDescription),
                          ),
                      ],
                    ),
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(
                        field.errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (question.isOther &&
                      _selections[question.id] == _otherValue(question.id)) ...[
                    const SizedBox(height: 8),
                    _buildTextField(
                      context,
                      question,
                      enabled,
                      label: l10n.toolUserInputOther,
                    ),
                  ],
                ],
              );
            },
          )
        else
          _buildTextField(
            context,
            question,
            enabled,
            label: l10n.toolUserInputAnswer,
          ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context,
    ToolUserInputQuestion question,
    bool enabled, {
    required String label,
  }) {
    final l10n = context.l10n;
    final secretVisible = _visibleSecrets.contains(question.id);
    return TextFormField(
      key: ValueKey('tool-user-input-${question.id}-text'),
      controller: _textControllers[question.id],
      enabled: enabled,
      obscureText: question.isSecret && !secretVisible,
      minLines: question.isSecret ? 1 : 2,
      maxLines: question.isSecret ? 1 : 4,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: question.isSecret
            ? IconButton(
                tooltip: secretVisible
                    ? l10n.toolUserInputHideSecret
                    : l10n.toolUserInputShowSecret,
                onPressed: enabled
                    ? () {
                        setState(() {
                          if (secretVisible) {
                            _visibleSecrets.remove(question.id);
                          } else {
                            _visibleSecrets.add(question.id);
                          }
                        });
                      }
                    : null,
                icon: Icon(
                  secretVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
      validator: (value) {
        if (!_needsTextAnswer(question)) {
          return null;
        }
        return value?.trim().isEmpty ?? true
            ? l10n.toolUserInputAnswerRequired
            : null;
      },
    );
  }

  bool _needsTextAnswer(ToolUserInputQuestion question) {
    if (!question.hasOptions) {
      return true;
    }
    return _selections[question.id] == _otherValue(question.id);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final callback = widget.onSubmit;
    if (callback == null) {
      return;
    }

    final answers = <String, List<String>>{};
    for (final question in widget.questions) {
      final selection = _selections[question.id];
      if (question.hasOptions && selection != _otherValue(question.id)) {
        answers[question.id] = [selection!];
        continue;
      }
      final answer = _textControllers[question.id]!.text.trim();
      answers[question.id] = ['user_note: $answer'];
    }

    setState(() => _submitting = true);
    try {
      await Future<void>.sync(() => callback(answers));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _syncQuestions() {
    final questionIds = widget.questions.map((question) => question.id).toSet();
    final removedIds = _textControllers.keys
        .where((id) => !questionIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      _textControllers.remove(id)?.dispose();
      _selections.remove(id);
      _visibleSecrets.remove(id);
    }
    for (final question in widget.questions) {
      _textControllers.putIfAbsent(question.id, TextEditingController.new);
      final selection = _selections[question.id];
      final validOptions = question.options
          ?.map((option) => option.label)
          .toSet();
      if (selection != null &&
          selection != _otherValue(question.id) &&
          !(validOptions?.contains(selection) ?? false)) {
        _selections.remove(question.id);
      }
    }
  }
}

String _otherValue(String questionId) => '__sadcoder_other__$questionId';
