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
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-model-command-model',
              controller: _modelController,
              label: l10n.modelOverride,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-model-command-effort',
              controller: _effortController,
              label: l10n.effortOverride,
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
}

class _ModelListPicker extends StatelessWidget {
  const _ModelListPicker({
    required this.controller,
    required this.modelController,
  });

  final ModelListController? controller;
  final TextEditingController modelController;

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
                  modelController.text = value;
                }
              },
            ),
          ),
        );
      },
    );
  }
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
