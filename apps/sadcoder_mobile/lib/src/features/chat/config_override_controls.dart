import 'package:flutter/material.dart';

import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';
import 'config_override_labels.dart';

class ConfigOverrideSourceChip extends StatelessWidget {
  const ConfigOverrideSourceChip({
    super.key,
    required this.label,
    required this.value,
    required this.source,
  });

  final String label;
  final String? value;
  final CodexConfigOverrideSource source;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trimmed = value?.trim();
    final detail = trimmed == null || trimmed.isEmpty
        ? configOverrideSourceLabel(l10n, source)
        : '$trimmed / ${configOverrideSourceLabel(l10n, source)}';
    return Text(
      '$label: $detail',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class ConfigOverrideField extends StatelessWidget {
  const ConfigOverrideField({
    super.key,
    required this.keyValue,
    required this.controller,
    required this.label,
  });

  final String keyValue;
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey(keyValue),
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
