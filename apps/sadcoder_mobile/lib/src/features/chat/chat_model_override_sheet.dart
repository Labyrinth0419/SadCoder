import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../models/model_labels.dart';
import '../../models/model_list_controller.dart';
import '../../models/model_list_reader.dart';
import 'chat_override_scope.dart';
import 'config_override_controls.dart';

class ChatModelOverrideResult {
  const ChatModelOverrideResult({
    required this.scope,
    required this.model,
    required this.effort,
  });

  final ChatOverrideScope scope;
  final String model;
  final String effort;
}

class ChatModelOverrideSheet extends StatefulWidget {
  const ChatModelOverrideSheet({
    super.key,
    required this.controller,
    this.modelListController,
  });

  final CodexConfigOverrideController controller;
  final ModelListController? modelListController;

  @override
  State<ChatModelOverrideSheet> createState() => _ChatModelOverrideSheetState();
}

class _ChatModelOverrideSheetState extends State<ChatModelOverrideSheet> {
  late ChatOverrideScope _scope;
  late final TextEditingController _modelController;
  late final TextEditingController _effortController;

  @override
  void initState() {
    super.initState();
    _scope = ChatOverrideScope.turn;
    final overrides = chatOverridesForScope(widget.controller, _scope);
    _modelController = TextEditingController(text: overrides.model ?? '');
    _effortController = TextEditingController(text: overrides.effort ?? '');
    unawaited(widget.modelListController?.refresh());
  }

  @override
  void dispose() {
    _modelController.dispose();
    _effortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.modelCommandTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ChatOverrideScopeSelector(
              scope: _scope,
              onChanged: (scope) {
                setState(() {
                  _scope = scope;
                  _loadScopeValues();
                });
              },
            ),
            const SizedBox(height: 12),
            _ModelListPicker(
              controller: widget.modelListController,
              modelController: _modelController,
              onModelSelected: _selectModel,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-model-command-model',
              controller: _modelController,
              label: l10n.modelOverride,
            ),
            const SizedBox(height: 12),
            _ModelEffortPicker(
              controller: widget.modelListController,
              modelController: _modelController,
              effortController: _effortController,
            ),
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.approvalCancel),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-model-command-apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyModelOverride),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      ChatModelOverrideResult(
        scope: _scope,
        model: _modelController.text,
        effort: _effortController.text,
      ),
    );
  }

  void _loadScopeValues() {
    final overrides = chatOverridesForScope(widget.controller, _scope);
    _modelController.text = overrides.model ?? '';
    _effortController.text = overrides.effort ?? '';
  }

  void _selectModel(CodexModelSummary model) {
    _modelController.text = model.id;
    final currentEffort = _effortController.text.trim();
    if (currentEffort.isEmpty || model.supportedReasoningEfforts.isEmpty) {
      return;
    }
    final supported = model.supportedReasoningEfforts.any(
      (effort) => effort.id == currentEffort,
    );
    if (!supported) {
      _effortController.clear();
    }
  }
}

class _ModelListPicker extends StatelessWidget {
  const _ModelListPicker({
    required this.controller,
    required this.modelController,
    required this.onModelSelected,
  });

  final ModelListController? controller;
  final TextEditingController modelController;
  final ValueChanged<CodexModelSummary> onModelSelected;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.models.isEmpty) {
          return const SizedBox.shrink();
        }
        final selectedModel =
            controller.models.any((model) => model.id == modelController.text)
            ? modelController.text
            : null;
        return InputDecorator(
          decoration: InputDecoration(
            labelText: context.l10n.modelList,
            border: const OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('chat-model-command-model-list'),
              value: selectedModel,
              isExpanded: true,
              itemHeight: null,
              selectedItemBuilder: (context) => [
                for (final model in controller.models)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      codexModelDisplayLabel(context, model),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              items: [
                for (final model in controller.models)
                  DropdownMenuItem(
                    value: model.id,
                    child: _ModelPickerMenuItem(model: model),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  final model = controller.models.firstWhere(
                    (model) => model.id == value,
                  );
                  onModelSelected(model);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _ModelEffortPicker extends StatelessWidget {
  const _ModelEffortPicker({
    required this.controller,
    required this.modelController,
    required this.effortController,
  });

  final ModelListController? controller;
  final TextEditingController modelController;
  final TextEditingController effortController;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return _fallbackField(context);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: modelController,
          builder: (context, modelValue, _) {
            final selectedModel = _modelForId(
              controller.models,
              modelValue.text,
            );
            if (selectedModel == null ||
                selectedModel.supportedReasoningEfforts.isEmpty) {
              return _fallbackField(context);
            }
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: effortController,
              builder: (context, effortValue, _) => _ModelEffortDropdown(
                model: selectedModel,
                currentEffort: effortValue.text.trim(),
                onChanged: (value) => effortController.text = value,
              ),
            );
          },
        );
      },
    );
  }

  Widget _fallbackField(BuildContext context) {
    return ConfigOverrideField(
      keyValue: 'chat-model-command-effort',
      controller: effortController,
      label: context.l10n.effortOverride,
    );
  }
}

class _ModelEffortDropdown extends StatelessWidget {
  const _ModelEffortDropdown({
    required this.model,
    required this.currentEffort,
    required this.onChanged,
  });

  final CodexModelSummary model;
  final String currentEffort;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final efforts = <String, CodexModelReasoningEffort>{
      for (final effort in model.supportedReasoningEfforts) effort.id: effort,
    };
    final hasCustomCurrent =
        currentEffort.isNotEmpty && !efforts.containsKey(currentEffort);
    final values = <String>[
      '',
      ...efforts.keys,
      if (hasCustomCurrent) currentEffort,
    ];
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.effortOverride,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const ValueKey('chat-model-command-effort-list'),
          value: currentEffort,
          isExpanded: true,
          itemHeight: null,
          selectedItemBuilder: (context) => [
            for (final value in values)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _effortLabel(
                    l10n,
                    model,
                    value,
                    custom: hasCustomCurrent && value == currentEffort,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          items: [
            DropdownMenuItem(
              key: const ValueKey('chat-model-command-effort-option-default'),
              value: '',
              child: _ReasoningEffortMenuItem(
                title: _effortLabel(l10n, model, ''),
                description: l10n.modelEffortServerDefaultDescription,
              ),
            ),
            for (final effort in efforts.values)
              DropdownMenuItem(
                key: ValueKey('chat-model-command-effort-option-${effort.id}'),
                value: effort.id,
                child: _ReasoningEffortMenuItem(
                  title: _effortLabel(l10n, model, effort.id),
                  description: effort.description,
                ),
              ),
            if (hasCustomCurrent)
              DropdownMenuItem(
                key: const ValueKey('chat-model-command-effort-option-custom'),
                value: currentEffort,
                child: _ReasoningEffortMenuItem(
                  title: _effortLabel(l10n, model, currentEffort, custom: true),
                  description: l10n.modelEffortNotAdvertised,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _ReasoningEffortMenuItem extends StatelessWidget {
  const _ReasoningEffortMenuItem({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDescription = description.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (showDescription) ...[
            const SizedBox(height: 2),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

CodexModelSummary? _modelForId(List<CodexModelSummary> models, String modelId) {
  final normalized = modelId.trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final model in models) {
    if (model.id == normalized) {
      return model;
    }
  }
  return null;
}

String _effortLabel(
  AppLocalizations l10n,
  CodexModelSummary model,
  String effort, {
  bool custom = false,
}) {
  if (effort.isEmpty) {
    return l10n.modelEffortServerDefault(model.defaultReasoningEffort);
  }
  if (custom) {
    return l10n.modelEffortCustom(effort);
  }
  return effort == model.defaultReasoningEffort
      ? l10n.modelEffortDefaultOption(effort)
      : effort;
}

class _ModelPickerMenuItem extends StatelessWidget {
  const _ModelPickerMenuItem({required this.model});

  final CodexModelSummary model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final capabilitySummary = codexModelCapabilitySummary(context, model);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            codexModelDisplayLabel(context, model),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (capabilitySummary != null) ...[
            const SizedBox(height: 2),
            Text(
              capabilitySummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
